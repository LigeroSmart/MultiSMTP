# --
# Kernel/System/Email/MultiSMTP.pm - the global email send module
# Copyright (C) 2001-2010 OTRS AG, http://otrs.org/
# Extensions Copyright (C) 2006-2012 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Frank(dot)Oberender(at)cape(dash)it(dot)de
#
# --
# $Id: MultiSMTP.pm,v 1.29 2010/01/12 15:55:38 martin Exp $
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Email::MultiSMTP;

use strict;
use warnings;

use Kernel::System::EmailParser;
use Kernel::System::MultiSMTP;
use Kernel::System::Email::SMTP;
use Kernel::System::Email::SMTPS;
# MultiSMTP-capeIT for OTRS-Framwork 2.4.x
#use Kernel::System::Email::SMTPTLS;
# EO MultiSMTP-capeIT for OTRS-Framwork 2.4.x
use Kernel::System::Email::MultiSMTP::SMTP;
use Kernel::System::Email::MultiSMTP::SMTPS;
# MultiSMTP-capeIT for OTRS-Framwork 2.4.x
#use Kernel::System::Email::MultiSMTP::SMTPTLS;
# EO MultiSMTP-capeIT for OTRS-Framwork 2.4.x


use vars qw($VERSION);
$VERSION = qw($Revision: 1.29 $) [1];

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # check all needed objects
    for (qw(ConfigObject LogObject EncodeObject MainObject DBObject TimeObject)) {
        die "Got no $_" if ( !$Self->{$_} );
    }

    # create needed object
    $Self->{MSMTPObject}  = Kernel::System::MultiSMTP->new( %Param );# MultiSMTP for OTRS-Framwork 2.4.x
# MultiSMTP-capeIT for OTRS-Framwork 2.4.x
    #$Self->{ParserObject} = Kernel::System::EmailParser->new(
        #%{$Self},
        #Mode  => 'Standalone',
        #Debug => 0,
    #);
# EO MultiSMTP-capeIT for OTRS-Framwork 2.4.x

    return $Self;
}

sub Check {
    return (Successful => 1, MultiSMTP => shift );
}

sub Send {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Header Body ToArray)) {
        if ( !$Param{$_} ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    my $SMTPObject;
    if ( !$Param{From} ) {

        # use standard SMTP module as fallback
        my $Module  = $Self->{ConfigObject}->Get('MultiSMTP::Fallback');
        $SMTPObject = $Module->new( %{$Self} );
        $SMTPObject->Send( %Param );
        return;
    }

# MultiSMTP-capeIT for OTRS-Framwork 2.4.x
    #my $PlainFrom = $Self->{ParserObject}->GetEmailAddress(
        #Email => $Param{From},
    #);
    my $PlainFrom = '';
    for my $EmailSplit ( Mail::Address->parse( $Param{From} ) ) {
        $PlainFrom = $EmailSplit->address();
    }
    $PlainFrom = '' if $PlainFrom !~ /@/;

# EO MultiSMTP-capeIT for OTRS-Framwork 2.4.x

    my %SMTP = $Self->{MSMTPObject}->SMTPGetForAddress(
        Address => $PlainFrom,
    );

    if ( !%SMTP ) {

        # use standard SMTP module as fallback
        my $Module  = $Self->{ConfigObject}->Get('MultiSMTP::Fallback');
        $SMTPObject = $Module->new( %{$Self} );
        $SMTPObject->Send( %Param );
        return;
    }

    $SMTP{Password} = $SMTP{PasswordDecrypted};

    my $Module  = 'Kernel::System::Email::MultiSMTP::' . $SMTP{Type};
    $SMTPObject = $Module->new( %{$Self}, %SMTP );

    $Self->{LogObject}->Log(
        Priority => 'notice',
        Message  => "Use MultiSMTP $Module",
    );

    $Self->{LogObject}->Log(
        Priority => 'notice',
        Message  => sprintf "Use SMTP %s/%s (%s)", $SMTP{Host}, $SMTP{User}, $SMTP{ID},
    );

    return if !$SMTPObject;

    $SMTPObject->Send( %Param );

    return 1;
}

1;
