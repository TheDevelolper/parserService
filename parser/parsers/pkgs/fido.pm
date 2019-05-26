#!/usr/bin/perl

# Fido Perl Module
# Created by Donald Jones
# 15th March 2007

=head1 DESCRIPTION

C<fido.pm> is a Perl module which decodes data fields for RSS INT L2_L3 messages

=head1 NAME

fido.pm - L2 L3 decode messages

=head1 SYNOPSIS

    use fido;

    fido_setDirection;

    fido_parseRssIntMsg;

=cut

package pkgs::fido;

require Exporter;

@ISA =      qw(Exporter);

@EXPORT =   qw(
               fido_setDirection
               fido_parseRssIntMsg
               fido_parseDRIFilterMsg
              );

use vars    qw($debug
               $L3_length
               $Direction
);

use strict;
#use diagnostics;


$debug        = 0;

=head1 GLOBALS

These are global variables accessible to the test scripts

=cut

my %l3RRMsg_lkup = (
    # Layer 3 - Radio Resource (BSSMAP)

    '02' => 'sys_info_two_bis',
    '05' => 'sys_info_five_bis',
    '0a' => 'partial_release',
    '0d' => 'chan_release',
    '0f' => 'partial_release_comp',
    '10' => 'chan_mode_mod',
    '12' => 'rr_status',
    '13' => 'classmark_enq',
    '14' => 'freq_redef',
    '15' => 'measure_report',
    '16' => 'classmark_chg',
    '17' => 'chan_mode_mod_ack',
    '18' => 'sys_info_eight',
    '19' => 'sys_info_one',
    '1a' => 'sys_info_two',
    '1b' => 'sys_info_three',
    '1c' => 'sys_info_four',
    '1d' => 'sys_info_five',
    '1e' => 'sys_info_six',
    '1f' => 'sys_info_seven',
    '21' => 'paging_req_one',
    '22' => 'paging_req_two',
    '24' => 'paging_req_three',
    '27' => 'paging_resp',
    '28' => 'hando_fail',
    '29' => 'assign_comp',
    '2b' => 'hando_cmd',
    '2c' => 'hando_comp',
    '2d' => 'phys_info',
    '2e' => 'assign_cmd',
    '2f' => 'assign_fail',
    '32' => 'cipher_md_comp',
    '35' => 'cipher_md_cmd',
    '39' => 'immed_assign_extd',
    '3a' => 'immed_assign_rej',
    '3b' => 'additional_assign',
    '3f' => 'immed_assign');


    # Layer 3 - Mobility Managment (BSSMAP)
my %l3MMMsg_lkup = (
    '01' => 'imsi_detach_ind',
    '02' => 'location_update_acc',
    '04' => 'location_update_rej',
    '08' => 'location_update_req',

    '11' => 'auth_rej',
    '12' => 'auth_req',
    '14' => 'auth_resp',
    '18' => 'identity_req',
    '19' => 'identity_resp',
    '1a' => 'tmsi_realloc_cmd',
    '1b' => 'tmsi_realloc_comp',

    '21' => 'cm_service_acc',
    '22' => 'cm_service_rej',
    '23' => 'cm_service_abort',
    '24' => 'cm_service_req',
    '28' => 'cm_restablish',
    '29' => 'abort',

    '31' => 'mm_status');

    # Layer 3 - Call Control (DTAP)

my %l3CCMsg_lkup = (
    '01' => 'alerting',
    '02' => 'call_proceed',
    '03' => 'progress',
    '05' => 'setup',
    '07' => 'connect',
    '08' => 'call_confirmed',
    '0e' => 'emergency_setup',
    '0f' => 'connect_ack',

    '10' => 'user_info',
    '13' => 'modify_rej',
    '17' => 'modify',
    '18' => 'hold',
    '19' => 'hold_ack',
    '1a' => 'hold_rej',
    '1c' => 'retrieve',
    '1d' => 'retrieve_ack',
    '1e' => 'retrieve_rej',
    '1f' => 'modify_comp',

    '25' => 'disconnect',
    '2a' => 'release_comp',
    '2d' => 'release',

    '31' => 'stop_dtmf',
    '32' => 'stop_dtmf_ack',
    '34' => 'status_enquiry',
    '35' => 'start_dtmf',
    '36' => 'start_dtmf_ack',
    '37' => 'start_dtmf_rej',
    '39' => 'congestion_ctrl',
    '3a' => 'facility',
    '3d' => 'status',
    '3e' => 'notify');

    # Layer 3 - SMS (DTAP)
my $l3SMSMsg_lkup = (
    '01' => 'sms_cp_data',
    'xx' => 'sms_cp_ack',
    'yy' => 'sms_cp_error');


BEGIN
{
    return 1;
}


my @Data_el;
#--------------------------------------------------------------------------

sub gsm_bits
{
    my($byte_arr_hash, $byte_pos, $bit_pos, $bit_len) = @_;
    my @byte_array = @{$byte_arr_hash};
    my $total = 0;  # Initialize the running total

    while( $bit_len > 0 )
    {
        # First calculate the number of bits within the first byte to take

        my $num_bits = &min($bit_pos, $bit_len);

        $total *= 2 ** $num_bits;# left shift to make room for incoming bits

        # Add in the next chunk of bits

        $total += &bits($byte_array[$byte_pos], $bit_pos, $num_bits);

        $bit_len -= $num_bits;  # account for the bits just saved
        $byte_pos++;            # advance to the next byte
        $bit_pos = 8;           # all bytes after the first start at the left

        ;
    }

    ($total);
}

#--------------------------------------------------------------------------
# Bits returns the decimal value of a range of bits within
# a byte.  The arguments are the ASCII string of the byte to decode (in hex)
# and the left-most bit position, and the number of bits to decode.
# Bit positions are numbered right to left from 1 to 8,
# starting with 1 on the *right*.

sub bits
{
    my($byte, $from, $num_bits) = @_;
    my($mask, $byteval, $tempval);

    return unless defined $byte;

    # Convert ASCII string to byte value
    $byteval = &byte_value($byte);
    #print "Byte: 0x$byte = $byteval From $from, #bits = $num_bits\n";

    # Generate mask of num_bits 1's
    $mask = 2**$num_bits - 1;

    # Shift into position: note we need to shift the RIGHTMOST bit into
    # position, so we need to shift by from - num_bits
    $mask <<= ($from - $num_bits);

    # Apply mask
    $tempval = $byteval & $mask;

    # Shift value back to the right
    $tempval >>= ($from - $num_bits);

    return $tempval;
}

#--------------------------------------------------------------------------
sub byte_value
{
    my($byte) = @_;

    return unless defined $byte;
    my $top_nib    = nib_val(substr($byte, 0, 1));
    my $bottom_nib = nib_val(substr($byte, 1, 1));

    #print "Byte_Value: Byte: $byte = \'$top_nib\' \'$bottom_nib\'\n";
    my $ret_val = $top_nib *16 + $bottom_nib ;
    #print "ret_val: $ret_val\n";
    return $ret_val;
    #return (nib_val(substr($byte, 1, 1)) * 16 + &nib_val(substr($byte, 2, 1)));
}

#--------------------------------------------------------------------------
sub nib_val
{
    my($nibble) = @_;
    if( $nibble eq 'a' || $nibble eq 'A' )
    {
        return(10);
    }
    if( $nibble eq 'b' || $nibble eq 'B' )
    {
        return(11);
    }
    if( $nibble eq 'c' || $nibble eq 'C' )
    {
        return(12);
    }
    if( $nibble eq 'd' || $nibble eq 'D' )
    {
        return(13);
    }
    if( $nibble eq 'e' || $nibble eq 'E' )
    {
        return(14);
    }
    if( $nibble eq 'f' || $nibble eq 'F' )
    {
        return(15);
    }
    if( $nibble >= 0 && $nibble <= 9 )
    {
        return($nibble);
    }

    return (0);
}

#--------------------------------------------------------------------------

sub min
{
    my($current_min) = $_[1];
    my($counter);
    for($counter=2;$counter<=$#_;$counter++)
    {
        if($_[$counter]<$current_min)
        {
            $current_min=$_[$counter];
        }
    }
}

#--------------------------------------------------------------------------

sub L3_cc_decode
{
    my($msg_type) = @_;
    if (&bits($msg_type, 7, 1) == 1)
    {
        return ($l3CCMsg_lkup{sprintf('%02x', &bits($msg_type, 6, 6))});
    }
    else
    {
        return ($l3CCMsg_lkup{$msg_type});
    }
}

#--------------------------------------------------------------------------

sub L3_mm_decode
{
    my($msg_type) = @_;
    if( &bits($msg_type, 7, 1) == 1 )
    {
        return($l3MMMsg_lkup{sprintf('%02x', &bits($msg_type, 6, 6))});
    }
    else
    {
        return($l3MMMsg_lkup{$msg_type});
    }
}

#--------------------------------------------------------------------------

sub L3_rr_decode
{
    my($msg_type) = @_;
    ($l3RRMsg_lkup{$msg_type});
}

#--------------------------------------------------------------------------

my $Index;

sub decode_measurement_report
{
    my $channel_str = &decode_channel($Data_el[2]);

    my $meas_result_iei = $Data_el[3];
    my $meas_result_num = $Data_el[4];

    $Index = 5;
    my $uplink_str = &uplink_decode();

    #BS Power
    my $bs_power_iei = $Data_el[$Index];
    my $bs_power = &bits($Data_el[$Index + 1], 5, 5);
    $Index = $Index + 2;

    #L1 information
    my $l1_info_iei = $Data_el[$Index];
    my $l1_ms_power = &bits($Data_el[$Index + 1], 8, 5);
    my $l1_ms_adv = &bits($Data_el[$Index + 2], 8, 6);
    $Index = $Index + 3;

    #Measurement result
    my $measure_results_str = &measure_result_decode();
    if( $measure_results_str eq '[ invalid measurement report ]' )
    {
        return(sprintf('(%s) %s', $channel_str, $measure_results_str));
    }
    my $cell_str = &get_cell_info();

    #Relative timing advance
    my $rel_adv_f = $Data_el[$Index + 17];
    my $rel_adv_s = $Data_el[$Index + 18];

    return(sprintf('(%s) up(%s pw%d) down(%s pw%d ta%d) %s',
                   $channel_str, $uplink_str, $l1_ms_power, $measure_results_str,
                   $bs_power, $l1_ms_adv, $cell_str));
}

#--------------------------------------------------------------------------
# Decode all of the measurement report 4.08 contents execept the cell info
my $numcells;

sub measure_result_decode
{
    my $rxlev_ful = &bits($Data_el[$Index + 1], 6, 6);
    my $dtx_used = &bits($Data_el[$Index + 1], 7, 1);
    my $rxlev_sub = &bits($Data_el[$Index + 2], 6, 6);
    if( &bits($Data_el[$Index + 2], 7, 1) == 1 )
    {
        $Index = $Index + 17;
        return '[ invalid measurement report ]';
    }

    my $rxqual_ful = &bits($Data_el[$Index + 3], 7, 3);
    my $rxqual_sub = &bits($Data_el[$Index + 3], 4, 3);
    $numcells = &gsm_bits(*Data_el, $Index + 3, 1, 3);

    return(sprintf('rxlev f%d s%d rxqual f%d s%d dtx%d',
                   $rxlev_ful, $rxlev_sub, $rxqual_ful, $rxqual_sub, $dtx_used));
}

#---------------------------------------------------------------------------
# Decode just the cell information contained in the measurement report

sub get_cell_info
{
    my %rxlev_cell;
    my %bcch_cell;
    my %bsic_cell;

    $rxlev_cell{1} = &gsm_bits(*Data_el, $Index + 4, 6, 6);
    $bcch_cell{1}  = &gsm_bits(*Data_el, $Index + 5, 8, 5);
    $bsic_cell{1}  = &gsm_bits(*Data_el, $Index + 5, 3, 6);

    $rxlev_cell{2} = &gsm_bits(*Data_el, $Index + 6, 5, 6);
    $bcch_cell{2}  = &gsm_bits(*Data_el, $Index + 7, 7, 5);
    $bsic_cell{2}  = &gsm_bits(*Data_el, $Index + 9, 2, 6);

    $rxlev_cell{3} = &gsm_bits(*Data_el, $Index + 8, 4, 6);
    $bcch_cell{3}  = &gsm_bits(*Data_el, $Index + 9, 6, 5);
    $bsic_cell{3}  = &gsm_bits(*Data_el, $Index + 9, 1, 6);

    $rxlev_cell{4} = &gsm_bits(*Data_el, $Index + 10, 3, 6);
    $bcch_cell{4}  = &gsm_bits(*Data_el, $Index + 11, 5, 5);
    $bsic_cell{4}  = &gsm_bits(*Data_el, $Index + 12, 8, 6);

    $rxlev_cell{5} = &gsm_bits(*Data_el, $Index + 12, 2, 6);
    $bcch_cell{5}  = &gsm_bits(*Data_el, $Index + 13, 4, 5);
    $bsic_cell{5}  = &gsm_bits(*Data_el, $Index + 14, 7, 6);

    $rxlev_cell{6} = &gsm_bits(*Data_el, $Index + 14, 1, 6);
    $bcch_cell{6}  = &gsm_bits(*Data_el, $Index + 15, 3, 5);
    $bsic_cell{6}  = &gsm_bits(*Data_el, $Index + 16, 6, 6);

    #format the string that will be returned

    my $temp_str = '';

    for( my $i = 1; $i <= $numcells; $i++ )
    {
        my $string = sprintf('%s', $temp_str);
        $temp_str  = sprintf('%sr%d,f%d,b%d ',
                             $string, $rxlev_cell{$i}, $bcch_cell{$i}, $bsic_cell{$i});
    }

    return $temp_str;
}

#--------------------------------------------------------------------------

sub uplink_decode
{
    my $iei       = &bits($Data_el[5], 8, 8);
    my $len       = &bits($Data_el[6], 6, 6);
    my $rx_full   = &bits($Data_el[7], 6, 6);
    my $dtx_used  = &bits($Data_el[7], 7, 1);
    my $rx_sub    = &bits($Data_el[8], 6, 6);
    my $rx_f_qual = &bits($Data_el[9], 6, 3);
    my $rx_s_qual = &bits($Data_el[9], 3, 3);

    $Index = $Index + $len + 2;

    return(sprintf('rxlev f%d s%d, rxqual f%d s%d, dtx%d',
                   $rx_full, $rx_sub, $rx_f_qual, $rx_s_qual, $dtx_used));
}

#--------------------------------------------------------------------------

sub decode_ph_data_indication
{
    # channel is assumed to be in data_el[2] qqq
    (&decode_ph_data_general(4));
}

#--------------------------------------------------------------------------

sub decode_ph_data_request
{
    # channel is assumed to be in data_el[2] qqq
    (&decode_ph_data_general(4));
}

#--------------------------------------------------------------------------

sub decode_ph_fast_data_indication
{
    # channel is assumed to be in data_el[2] qqq
    (&decode_ph_data_general(4));
}

#--------------------------------------------------------------------------

sub decode_ph_fast_data_request
{
    # channel is assumed to be in data_el[2] qqq
    (&decode_ph_data_general(3));
}

#--------------------------------------------------------------------------

sub decode_rss_page_info
{
    my($msg_type) = @_;
    # Decode the radio channel
    my $Channel_str = &decode_channel($Data_el[2]);

    my $Page_group = substr($Data_el[3],2,1);
    my $Ms_identity = &decode_ms_identity();
    return( sprintf('(%s)                ( Grp %s %s )',
                     $Channel_str, $Page_group, $Ms_identity));
}

#--------------------------------------------------------------------------

sub decode_ms_identity
{
    my $length = $Data_el[4];

    # Get the Type of Identity
    my $identity_bits = &bits($Data_el[5],3,3);
    my $identity_type;
    my $identity;

    if( $identity_bits == 1 )
    {
        $identity_type = 'IMSI';
    }
    elsif( $identity_bits == 2 )
    {
        $identity_type = 'IMEI';
    }
    elsif( $identity_bits == 4 )
    {
        $identity_type = 'TMSI';
        #Get the TMSI
        $identity = $Data_el[6].$Data_el[7].$Data_el[8].$Data_el[9];
    }

    my $octet;
    #Get the IMSI or IMEI
    if( $identity_type eq 'IMSI' || $identity_type eq 'IMEI' )
    {
        $identity = substr($Data_el[5],1,1);
        $octet = 2;
        while( $octet <= $length )
        {
            $identity = $identity.substr($Data_el[$octet+4],2,1);
            if( $octet == $length && &bits($Data_el[5],4,1) == 0 )
            {
                last;
            }
            $identity = $identity.substr($Data_el[$octet+4],1,1);
            $octet++;
        }

    }

    return( $identity_type." ".$identity);
}

#--------------------------------------------------------------------------

sub decode_rss_immed_assign
{
    (&decode_rss_immed_assign_general(3));
}

#--------------------------------------------------------------------------

sub decode_rss_immed_assign_rej
{
    (&decode_rss_immed_assign_general(3));
}

#--------------------------------------------------------------------------

sub decode_rss_immed_assign_general
{
    my($l2_start) = @_;

    # Decode the radio channel
    my $Channel_str = &decode_channel($Data_el[2]);

    # Decode Layer 2

    my $L2_type = &l2_decode($Data_el[$l2_start],
                             $Data_el[$l2_start + 1],
                             $Data_el[$l2_start + 2]);

    if( $L3_length > 0 )
    {
        # Layer 3 decode

        my $proto_dis = &bits($Data_el[$l2_start + 3], 4, 4);
        my $Msg_decode;

        # GET PD
        if( $proto_dis == 3 )
        {
            $Msg_decode = &L3_cc_decode($Data_el[$l2_start + 4]);
        }
        elsif( $proto_dis == 5 )
        {
            $Msg_decode = &L3_mm_decode($Data_el[$l2_start + 4]);
        }
        elsif( $proto_dis == 6 )
        {
            if( $Data_el[$l2_start + 4] eq '3f')
            {
                # Immediate Assignment
                return( sprintf('(%s)  %s  [ %s (RA %sh tadv %d) ]',
                        $Channel_str, $L2_type,
                        &L3_rr_decode($Data_el[$l2_start + 4]),
                                      $Data_el[$l2_start + 9],
                                      &bits($Data_el[$l2_start + 12], 6, 6)) );
            }
            elsif ($Data_el[$l2_start + 4] eq '3a')
            {
                # Immediate Assignment Reject
                return( sprintf('(%s)  %s  [ %s (RA %sh)]',
                                $Channel_str, $L2_type,
                                &L3_rr_decode($Data_el[$l2_start + 4]),
                                              $Data_el[$l2_start + 6]));
            }
            else
            {
                $Msg_decode = &L3_rr_decode($Data_el[$l2_start + 4]);
            }
        }

        return( sprintf('(%s)  %s  [ %s ]',
                        $Channel_str,
                        $L2_type,
                        $Msg_decode) );
    }
    else
    {
        return( sprintf('(%s)  %s',
                        $Channel_str,
                        $L2_type) );
    }
}


#---------------------------------------------------------------------------
# decodes RSS to DRI Ref Section 5.2.42 information

sub decode_ph_data_general
{
    my($l2_start) = @_;

    # Decode the radio channel
    #print "Data_el:\n";
    #print Dumper @Data_el;
    my $Channel_str = &decode_channel($Data_el[2]);
    #print "Channel_str: $Channel_str\n";

    # Decode Layer 2

    #print " L2: ".$ Data_el[ $l2_start ].",". $Data_el[ $l2_start + 1 ].",".$Data_el[$l2_start + 2]."\n";

    my $L2_type = &l2_decode($Data_el[$l2_start],
                             $Data_el[$l2_start + 1],
                             $Data_el[$l2_start + 2]);

    if( $L3_length > 0 )
    {
        # Layer 3 decode

        my $proto_dis = &bits($Data_el[$l2_start + 3], 4, 4);
        my $Msg_decode;

        # GET PD
        if( $proto_dis == 3 )
        {
            $Msg_decode = &L3_cc_decode($Data_el[$l2_start + 4]);
        }
        elsif( $proto_dis == 5 )
        {
            $Msg_decode = &L3_mm_decode($Data_el[$l2_start + 4]);
        }
        elsif( $proto_dis == 6 )
        {
            if( $Data_el[$l2_start + 4] eq '2e' )
            {
                # Assignment command

                $Msg_decode = sprintf('%s (%s)',
                                      &L3_rr_decode($Data_el[$l2_start + 4]),
                                      &decode_channel($Data_el[$l2_start + 5]));
            }
            else
            {
                $Msg_decode = &L3_rr_decode($Data_el[$l2_start + 4]);
            }
        }

        return( sprintf('(%s)  %s  [ %s ]',
                        $Channel_str,
                        $L2_type,
                        $Msg_decode) );
    }
    else
    {
        return( sprintf('(%s)  %s',
                        $Channel_str,
                        $L2_type) );
    }
}

#--------------------------------------------------------------------------

sub decode_rss_chnl_request
{
    my $Channel_str = &decode_channel($Data_el[2]);

    return (sprintf('(%s)                ( RA %sh )',
                    $Channel_str,
                    $Data_el[3]));
}

#--------------------------------------------------------------------------
sub l2_decode
{
    my($address_byte, $control_byte, $length_byte) = @_;

    # Layer 2
    my $cmd_bit = &bits($address_byte, 2, 1);
    my $poll_bit = &bits($control_byte, 5, 1);
    $L3_length = &bits($length_byte, 8, 6);

    my $cr_value;
    if( $Direction eq 'UPLINK' )
    {
        if( $cmd_bit == 0 )
        {
            $cr_value = 'C';
        }
        else
        {
            $cr_value = 'R';
        }
    }
    elsif( $Direction eq 'DOWNLINK' )
    {
        if( $cmd_bit == 0 )
        {
            $cr_value = 'R';
        }
        else
        {
            $cr_value = 'C';
        }
    }
    else
    {
        $cr_value = $cmd_bit;
    }

    my $poll_flag = $poll_bit;
    if( $poll_bit == 1 )
    {
        if( $cr_value eq 'C' )
        {
            $poll_flag = 'P';
        }
        elsif( $cr_value eq 'R' )
        {
            $poll_flag = 'F';
        }
    }
    else
    {
        $poll_flag = ' ';
    }

    my $recv_count;
    my $send_count;
    if( &bits($control_byte, 1, 1) == 0 )
    {
        $recv_count = &bits($control_byte, 8, 3);
        $send_count = &bits($control_byte, 4, 3);
        return( sprintf('I    %s r%d s%d',
                        $poll_flag,
                        $recv_count,
                        $send_count) );
    }
    elsif( &bits($control_byte, 4, 4) == 1 )
    {
        $recv_count = &bits($control_byte, 8, 3);

        return( sprintf('RR  %s  r%d   ',
                        $poll_flag,
                        $recv_count) );
    }
    elsif( &bits($control_byte, 4, 4) == 5 )
    {
        $recv_count = &bits($control_byte, 8, 3);
        return( sprintf('RNR  %s r%d  ',
                        $poll_flag,
                        $recv_count) );
    }
    elsif( &bits($control_byte, 4, 4) == 9 )
    {
        $recv_count = &bits($control_byte, 8, 3);
        return( sprintf('REJ  %s r%d  ',
                        $poll_flag,
                        $recv_count) );
    }
    elsif( &bits($control_byte, 4, 4) == 15 &&
           &bits($control_byte, 8, 3) == 1 )
    {
        return( sprintf('SABM %s      ', $poll_flag) );
    }
    elsif( &bits($control_byte, 4, 4) == 15 &&
           &bits($control_byte, 8, 3) == 0 )
    {
        return( sprintf('DM   %s      ', $poll_flag) );
    }
    elsif( &bits($control_byte, 4, 4) == 3 &&
           &bits($control_byte, 8, 3) == 0 )
    {
        return( sprintf('UI   %s      ', $poll_flag) );
    }
    elsif( &bits($control_byte, 4, 4) == 3 &&
           &bits($control_byte, 8, 3) == 2 )
    {
        return( sprintf('DISC %s      ', $poll_flag) );
    }
    elsif( &bits($control_byte, 4, 4) == 3 &&
           &bits($control_byte, 8, 3) == 3 )
    {
        return( sprintf('UA   %s      ', $poll_flag) );
    }

    return ('UI          ');
}

sub fido_parseRssIntMsg($@)
{
    my($ret_msg_type, $data_line) = @_;

    # Split the data line into individual tokens
    @Data_el = split(/\s/, $data_line);
    unshift(@Data_el, "ff");

    # The first byte is the message type
    my $Msg_type = $Data_el[1];

    if ($debug)
    {
        print "\nparserRssIntMsg\n***************\n";
        print "Ret Msg Type: $ret_msg_type\n";
        print "Data_line: $data_line\n";
        print Dumper @Data_el;
        print "Msg: $Msg_type\n";
    }


    # Decode the message based on the source, destination, and message type
    if    ($Msg_type eq '68') {return (&decode_rss_page_info());}
    elsif ($Msg_type eq '69') {return (&decode_rss_immed_assign());}
    elsif ($Msg_type eq '6a') {return (&decode_rss_immed_assign_rej());}
    elsif ($Msg_type eq '6b') {return (&decode_rss_chnl_request());}
    elsif ($Msg_type eq 'b0') {return (&decode_ph_data_indication());}
    elsif ($Msg_type eq 'b1') {return (&decode_ph_data_request());}
    elsif ($Msg_type eq 'b3') {return (&decode_ph_fast_data_indication());}
    elsif ($Msg_type eq 'b4') {return (&decode_ph_fast_data_request());}
    elsif ($Msg_type eq 'c0') {return (&decode_measurement_report());}
    else                      {return $ret_msg_type}
}

sub decode_channel
{
    my ($channel_byte) = @_;
    #$channel_byte = '12';
    #print "Channel_Byte: $channel_byte\n";

    # Calculate what type of radio channel this is
    my $Time_slot = &bits($channel_byte, 3, 3);

    if( &bits($channel_byte, 8, 5) == 1 )
    {
        return( sprintf('FACCH ts%d   ', $Time_slot) );
    }
    elsif( &bits($channel_byte, 8, 4) == 1 )
    {
        return( sprintf('FCH/H ts%d s%d',
                        $Time_slot, &bits($channel_byte, 4, 1)) );
    }
    elsif( &bits($channel_byte, 8, 3) == 1 )
    {
        return( sprintf('SD/4  ts%d s%d',
                        $Time_slot, &bits($channel_byte, 5, 2)) );
    }
    elsif( &bits($channel_byte, 8, 2) == 1 )
    {
        return( sprintf('SD/8  ts%d s%d',
                        $Time_slot, &bits($channel_byte, 6, 3)) );
    }
    elsif( &bits($channel_byte, 8, 5) == 16 )
    {
        return( sprintf('BCCH  ts%d   ', $Time_slot) );
    }
    elsif( &bits($channel_byte, 8, 5) == 17 )
    {
        return( sprintf('RACH  ts%d   ', $Time_slot) );
    }
    elsif( &bits($channel_byte, 8, 5) == 18 )
    {
        return( sprintf('P/AG  ts%d   ', $Time_slot) );
    }
    else
    {
        return( sprintf('%s ts%d', $channel_byte, $Time_slot) );
    }
}

sub fido_setDirection($$)
{
    my $Src_pid  = shift;
    my $Dest_pid = shift;
    if( $Src_pid == 32 )
    {
        if(    $Dest_pid == 33
            || $Dest_pid == 34
            || $Dest_pid == 31 )
        {
            $Direction = 'UPLINK';
        }
    }
    elsif( $Src_pid == 34 )
    {
        if( $Dest_pid == 32 )
        {
            $Direction = 'DOWNLINK';
        }
    }
    elsif ($Src_pid == 33)
    {
       if( $Dest_pid == 32 )
       {
           $Direction = 'DOWNLINK';
       }
   }
}

sub get_msg_code($)
{
   $_ = shift;
   #print "Testing: $_\n";
   if    (/PAGE/i)                {return '68'}
   elsif (/IMMED_ASSIGN_REJECT/i) {return '6a'}
   elsif (/IMMED_ASSIGN_REJECT/i) {return '69'}
   elsif (/CHNL_REQ/i)            {return '6b'}
   elsif (/FAST_DATA_IND/i)       {return 'b3'}
   elsif (/FAST_DATA_REQ/i)       {return 'b4'}
   elsif (/DATA_IND/i)            {return 'b0'}
   elsif (/DATA_REQ/i)            {return 'b1'}
   elsif (/MEAS/i)                {return 'c0'}
   else                           { return undef}
}

sub fido_parseDRIFilterMsg($$@)
{
    my($from, $ret_msg_type, $data_line) = @_;
    if ($debug)
    {
        print "\nparserRssDRIFilterMsg\n**************\n";
        print "From: $from\n";
        print "ret_msg_type: $ret_msg_type\n";
        print "Data: $data_line\n";
    }
    $Direction = 'UPLINK';
    $Direction = 'DOWNLINK' if $from =~ /rss/i;

    my $msg_code = get_msg_code($ret_msg_type);
    #die "Could not Convert Message Type: $ret_msg_type" unless defined $msg_code;
    return $ret_msg_type unless (defined $msg_code);
    #print "$ret_msg_type : $msg_code\n";

    # Reverse the data in data line
    my @split_data_line = split(/\s/, $data_line);
    my @rev_data_line = reverse @split_data_line[9..$#split_data_line];
    my $len = "0c";
    unshift (@rev_data_line, "00") if $msg_code =~ /b3/;
    unshift(@rev_data_line, $len);
    unshift(@rev_data_line, $msg_code);
    print "rev_data_line: @rev_data_line\n" if $debug;
    my $rev_data_line = join(' ', @rev_data_line);
    print "Direction: $Direction\n" if $debug;

    $ret_msg_type .= "[ ".fido_parseRssIntMsg($ret_msg_type, $rev_data_line). " ]";

    #return fido_parseRssIntMsg($ret_msg_type, $rev_data_line);
    return $ret_msg_type;
    #die;
}

1;

__END__
=head1 REPORTING BUGS

When reporting bugs/problems please include as much information as possible.
It may be difficult for me to reproduce the problem as almost every setup
is different.

A small logfile which yields the problem will probably be of help,
together with the execution output.

=head1 AUTHOR

Donald Jones <donald.starquality@gmail.com>

=head1 USE EXAMPLES

For an example of the use of parser see

=over 4

=item fido.pm

=back

=head1 CREDITS

Donald Jones <donald.starquality@gmail.com>

=head1 COPYRIGHT

Copyright (c) 2006 Donald Jones. All rights reserved.
This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut


