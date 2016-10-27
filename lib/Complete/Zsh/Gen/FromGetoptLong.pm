package Complete::Zsh::Gen::FromGetoptLong;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

use Getopt::Long::Util qw(parse_getopt_long_opt_spec);
use String::ShellQuote;

our %SPEC;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
                       gen_zsh_complete_from_getopt_long_script
                       gen_zsh_complete_from_getopt_long_spec
               );

sub _quote {
    local $_ = shift;
    s/[^A-Za-z0-9]+/_/g;
    $_ = "_$_" if /\A[0-9]/;
    "_$_";
}

$SPEC{gen_zsh_complete_from_getopt_long_spec} = {
    v => 1.1,
    summary => 'From Getopt::Long spec, generate completion '.
        'script for the zsh shell',
    description => <<'_',

This routine generate zsh completion script for each short/long option, enabling
zsh to display the options in a different color and showing description (if
specified) for each option.

Getopt::Long::Complete scripts are also supported.

_
    args => {
        spec => {
            summary => 'Getopt::Long options specification',
            schema => 'hash*',
            req => 1,
            pos => 0,
        },
        opt_desc => {
            summary => 'Description for each option',
            description => <<'_',

This is optional and allows adding description for the complete command. Each
key of the hash should correspond to the option name without the dashes, e.g.
`s`, `long`.

_
            schema => 'hash*',
        },
        cmdname => {
            summary => 'Command name to be completed',
            schema => 'str*',
            req => 1,
        },
        compname => {
            summary => 'Completer name, if there is a completer for option values',
            schema => 'str*',
        },
    },
    result => {
        schema => 'str*',
        summary => 'A script that can be put as FPATH/_PROG',
    },
};
sub gen_zsh_complete_from_getopt_long_spec {
    my %args = @_;

    my $gospec = $args{spec} or return [400, "Please specify 'spec'"];
    my $cmdname = $args{cmdname} or return [400, "Please specify cmdname"];
    my $compname = $args{compname};
    my $opt_desc = $args{opt_desc};

    my $qcompname = shell_quote($compname);

    my @res;
    push @res, "#compdef $cmdname\n";

    # define function to complete arg or option value
    my $val_func = _quote($cmdname);
    push @res, join(
        "",
        "$val_func() {\n",
        "  _values 'values' \${(uf)\"\$(COMP_SHELL=zsh COMP_LINE=\$BUFFER COMP_POINT=\$CURSOR $qcompname)\"}\n",
        "}\n",
    );

    push @res, "_arguments \\\n";
    for my $ospec (sort {
        # make sure <> is the last
        my $a_is_diamond = $a eq '<>' ? 1:0;
        my $b_is_diamond = $b eq '<>' ? 1:0;
        $a_is_diamond <=> $b_is_diamond || $a cmp $b
    } keys %$gospec) {
        my $res = parse_getopt_long_opt_spec($ospec)
            or die "Can't parse option spec '$ospec'";
        if ($res->{is_arg} && $compname) {
            push @res, "  '*:value:$val_func'\n";
        } else {
            $res->{min_vals} //= $res->{type} ? 1 : 0;
            $res->{max_vals} //= $res->{type} || $res->{opttype} ? 1:0;
            for my $o0 (@{ $res->{opts} }) {
                my @o = $res->{is_neg} && length($o0) > 1 ?
                    ($o0, "no$o0", "no-$o0") : ($o0);
                for my $o (@o) {
                    my $opt = length($o) == 1 ? "-$o" : "--$o";
                    my $desc = ($opt_desc ? $opt_desc->{$o} : undef) // '';
                    $desc =~ s/\[|\]/_/g;
                    push @res, "  " . shell_quote(
                        "$opt\[$desc\]" .
                            ($res->{min_vals} > 0 ? ":value:$val_func" : "")) .
                            "\n";
                }
            }
        }
    }
    [200, "OK", join("", @res)];
}

$SPEC{gen_zsh_complete_from_getopt_long_script} = {
    v => 1.1,
    summary => 'Generate zsh completion script from Getopt::Long script',
    description => <<'_',

This routine generate zsh `compadd` command for each short/long option, enabling
zsh to display the options in a different color and showing description (if
specified) for each option.

Getopt::Long::Complete scripts are also supported.

_
    args => {
        filename => {
            schema => 'filename*',
            req => 1,
            pos => 0,
            cmdline_aliases => {f=>{}},
        },
        cmdname => {
            summary => 'Command name to be completed, defaults to filename',
            schema => 'str*',
        },
        compname => {
            summary => 'Completer name',
            schema => 'str*',
        },
        skip_detect => {
            schema => ['bool', is=>1],
            cmdline_aliases => {D=>{}},
        },
    },
    result => {
        schema => 'str*',
        summary => 'A script that can be fed to the zsh shell',
    },
};
sub gen_zsh_complete_from_getopt_long_script {
    my %args = @_;

    my $filename = $args{filename};
    return [404, "No such file or not a file: $filename"] unless -f $filename;

    require Getopt::Long::Dump;
    my $dump_res = Getopt::Long::Dump::dump_getopt_long_script(
        filename => $filename,
        skip_detect => $args{skip_detect},
    );
    return $dump_res unless $dump_res->[0] == 200;

    my $cmdname = $args{cmdname};
    if (!$cmdname) {
        ($cmdname = $filename) =~ s!.+/!!;
    }
    my $compname = $args{compname};

    my $glspec = $dump_res->[2];

    # GL:Complete scripts can also complete arguments
    my $mod = $dump_res->[3]{'func.detect_res'}[3]{'func.module'} // '';
    if ($mod eq 'Getopt::Long::Complete') {
        $compname //= $cmdname;
        $glspec->{'<>'} = sub {};
    }

    gen_zsh_complete_from_getopt_long_spec(
        spec => $dump_res->[2],
        cmdname => $cmdname,
        compname => $compname,
    );
}

1;
# ABSTRACT: Generate zsh completion script from Getopt::Long spec/script

=head1 SYNOPSIS


=head1 SEE ALSO
