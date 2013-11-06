#!/usr/bin/perl
# Lucas Betschart - lclc <lucasbetschart@gmail.com>
# github.com/lclc/BitcoinSMSGateway
# AGPL (https://www.gnu.org/licenses/agpl-3.0.txt)
# October, 2013
##################################################
######### Settings ###############################
my $bitcoindUsername = 'bitcoinrpc';  #Bitcoind RPC Username from your bitcoin.conf
my $bitcoindPassword = 'MaEcGfpmwwR63PG6K4ADiMjxXwAL6Zg3eMLYZKg6HMg';  #Bitcoind RPC Password from your bitcoin.conf
my $bitcoindIP = 'localhost';
my $bitcoindPort = 8332;
my $loggingPath = $ENV{"HOME"}."/bitcoinSMSGateway.log"; # Path to log file

my %phoneNumbers = (  #generates a callback function for each number (e.g. http://yourserver.com:3000/Switzerland/)
		      "Switzerland" => "041112223344",
		      "USA" => "123456789"
		    );

my $debugMode = 0; # true (1) or false (0)
##################################################

use strict;
use warnings;
use Mojolicious::Lite;
use Mojo::Log;
use JSON::RPC::Client;
use Convert::Ascii85;
use IO::Uncompress::Gunzip qw(gunzip $GunzipError);
use Data::Dumper;

my $RPCClient = new JSON::RPC::Client;

$RPCClient->ua->credentials("$bitcoindIP:$bitcoindPort",
			 'jsonrpc',
			 $bitcoindUsername => $bitcoindPassword
			);
my $RPC_URI = "http://$bitcoindIP:$bitcoindPort/";

if(!$debugMode)
{
  app->mode('production');
}
my $log = Mojo::Log->new(path => $loggingPath, level => 'info' );

my %SMS;	# $SMS{concatRef} = "SMSContent"  (used to attach the parts of a splitted SMS)


foreach my $country (keys %phoneNumbers) {
  get "/$country" => sub {
    my $self = shift;
    my $host = $self->req->url->to_abs->host;
    
    no warnings 'uninitialized';
    my ($type, $to, $msisdn,$networkcode,$messageId,$messageTimestamp,$text,$concat,$concatRef,$concatTotal,$concatPart) = (0);
    # See https://docs.nexmo.com/index.php/messaging-sms-api/handle-inbound-message
    $type = $self->param('type'); #Expected values are: text (URL encoded, valid for standard GSM, Arabic, Chinese ... characters) or binary
    $to = $self->param('to'); #Recipient number (your long virtual number).
    $msisdn = $self->param('msisdn'); #Optional. Sender ID
    $networkcode = $self->param('network-code'); #Optional. Unique identifier of a mobile network MCCMNC. Wikipedia list here.
    $messageId = $self->param('messageId'); #Nexmo Message ID.
    $messageTimestamp = $self->param('message-timestamp'); #Time (UTC) when Nexmo started to push the message to your callback URL in the following format YYYY-MM-DD HH:MM:SS e.g. 2012-04-05 09:22:57
    
    $text = $self->param('text'); #Content of the message
    $concat = $self->param('concat'); #Set to true if a MO concatenated message is detected
    $concatRef = $self->param('concat-ref'); #Transaction reference, all message parts will shared the same transaction reference
    $concatTotal = $self->param('concat-total'); #The total number of parts in this concatenated message set
    $concatPart = $self->param('concat-part'); #The part number of this message within the set (starts at 1)
  
    $log->info("Received SMS at $country" . $phoneNumbers{$country} . " from: $msisdn");
    
    if($debugMode)
    {
      $self->render(text => " Country: $country</br>
			      Nr: $phoneNumbers{$country}</br>
			      Host: $host</br>
			      </br>
			      type: $type</br>
			      to: $to</br>
			      msisdn: $msisdn</br>
			      network-code: $networkcode</br>
			      messageId: $messageId</br>
			      message-timestamp: $messageTimestamp</br>
			      text: $text</br>
			      concat: $concat</br>
			      concat-ref: $concatRef</br>
			      concat-total: $concatTotal</br>
			      concat-part: $concatPart</br>
			    ");
    }
    else
    {
      $self->render(text => "OK");
    }
			  
    $SMS{$concatRef} = $SMS{$concatRef}.$text;
    if($concatTotal != 0 && $concatPart == $concatTotal)
    {
      sendTransaction( decodeTransaction($SMS{$concatRef}) );
      delete $SMS{$concatRef};
    }
  };
}

sub decodeTransaction
{
  my $encodedTransaction = shift;
  my $decodedTransaction;

  $encodedTransaction = Convert::Ascii85::decode($encodedTransaction)
    or $log->warn("decode ASCII85 failed: $!\n");
  gunzip \$encodedTransaction => \$decodedTransaction
    or $log->warn("gunzip failed: $GunzipError\n");
  
  return($decodedTransaction);
}

sub sendTransaction
{
  my $transaction = shift;
  
  my $sendObj = {
      method  => 'sendrawtransaction',
   #   method  => 'getinfo',
      params  => $transaction
   #   params  => []
   };
  
  $log->info("Adding transaction to blockchain: ".$transaction);
  
  my $res = $RPCClient->call( $RPC_URI, $sendObj );
 
  if ($res)
  {
      if ($res->is_error)
      {
	$log->warn("RPC-Call has error: ".$res->error_message);
	print "Error: $res->error_message";
      }
      else
      {
	$log->info("Send transaction to blockchain. RPC answer: ".Dumper($res->result));
	print Dumper($res->result);
      }
  }
  else
  {
    $log->warn("RPC-Call failed: ".$RPCClient->status_line);
    print "RPC-Call failed: " . $RPCClient->status_line;
  }
}

app->secret('dosomethingcat');
app->start;