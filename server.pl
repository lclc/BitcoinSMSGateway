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

my %phoneNumbers = (  #generates a callback function for each number (e.g. http://yourserver.com:3000/Switzerland/)
		      "Switzerland" => "041112223344",
		      "USA" => "123456789"
		    );
my $debugMode = 1; # true (1) or false (2)
##################################################

use strict;
use warnings;
use Mojolicious::Lite;
use JSON::RPC::Client;
use Data::Dumper;

my $nexmoHost = "nexmo.com"; #lclc testen
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

my %SMS;	# $SMS{concatRef} = "SMSContent"  (used to attach the parts of a splitted SMS)


foreach my $country (keys %phoneNumbers) {
  get "/$country" => sub {
    my $self = shift;
    my $host = $self->req->url->to_abs->host;
    
    if($host)# == $nexmoHost) #lclc testen
    {
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
      if($concatPart == $concatTotal)
      {
      #	lclc (encode and save in database ?)
	sendTransaction($SMS{$concatRef});
	delete $SMS{$concatRef};
      }
    }
    else
    {
      $self->render(text => '<iframe width="560" height="315" src="//www.youtube.com/embed/RpwVQ-FwhxM" frameborder="0" allowfullscreen></iframe>'); # changing this will release bad karma
    }
  };
}

sub sendTransaction
{
  my $transactionHash = shift;
  
  my $sendObj = {
   #   method  => 'sendrawtransaction',
      method  => 'getinfo',
   #   params  => $transactionHash
      params  => []
   };
   
  my $res = $RPCClient->call( $RPC_URI, $sendObj );
 
  if ($res)
  {
      if ($res->is_error)
      {
	print "Error: $res->error_message";
      }
      else
      {
	print Dumper($res->result);
      }
  }
  else
  {
      print "Error 2: " . $RPCClient->status_line;
  }
}

app->secret('dosomethingcat');
app->start;