#!/usr/bin/env perl
use open qw(:utf8 :std);
use warnings qw(FATAL utf8);
my $indent = 0;
my $in_block_quote = 0;
my $comment_prefix = '';
my $space_per_index = $ENV{INDENTATION} || 2;
my $saw_0a = 0;
my $saw_0d = 0;
my $saw_0d0a = 0;

sub report {
  my ($path, $saw_0a, $saw_0d, $saw_0d0a) = @_;
  if ($saw_0d0a && $saw_0a != $saw_0d) {
    print STDERR "mixed line endings (CRLF: $saw_0d0a; LF: $saw_0a; CR: $saw_0d): $old_argv\n";
  } elsif ($saw_0a && $saw_0d && $saw_0a != $saw_0d) {
    print STDERR "mixed line endings (LF: $saw_0a; CR: $saw_0d): $old_argv\n";
  }
}

$extension = '.orig';
LINE: while (<>) {
  if ($ARGV ne $old_argv) {
    $indent = 0;
    $in_block_quote = 0;
    $comment_prefix = '';
    report($old_argv, $saw_0a, $saw_0d, $saw_0d0a);
    $saw_0a = $saw_0d = $saw_0d0a = 0;
    if ($extension !~ /\*/) {
      $backup = $ARGV . $extension;
    }
    else {
      ($backup = $extension) =~ s/\*/$ARGV/g;
    }
    rename($ARGV, $backup);
    open(ARGV_OUT, ">$ARGV");
    select(ARGV_OUT);
    $old_argv = $ARGV;
  }

  $line=$_;
  ++$saw_0d0a if /\r\n/;
  ++$saw_0d if /\r/;
  ++$saw_0a if /\n/;
  s/\x{00a0}/ /g;
  s/(?<!")"([^"])+"/<>/; # ignore quoted strings
  s/\$\{.*?\}/<>/; # ignore variable substitutions
  if (s!(.*?)(?://|#).*?!$1!) {
    # ignore comments
    if ($comment_prefix eq '') {
      my $new_comment_prefix = $1;
      $comment_prefix = $new_comment_prefix if $new_comment_prefix =~ /^\s*$/;
    }
  } else {
    $comment_prefix = '';
  }
  if (! $in_block_quote || /"""/) {
    while (s/^(.*?)"""(.*)$//) {
      if ($in_block_quote) {
        $_ = $2;
      } else {
        $_ = $1;
      }
      $in_block_quote ^= 1;
    };
    s/^(\s*)\x{00a0}/$1 /g;
    # adjust current indentation
    $indent-- while (s/^\s*[\]}]//);
    my $indentation = " "x($indent*$space_per_index);
    if ($line !~ /\S/) {
      $line =~ s/^[\t ]+//;
    } else {
      if ($line =~ m!^\s*(?://|#)!) {
        $indentation = $comment_prefix;
      }
      $line =~ s/^[\t ]*/$indentation/;
    }
    # adjust indentation
    $indent++ while s/[\[{]//;
    $indent-- while s/[\]}]//;

    $line =~ s/^(\s*)\x{00a0}/$1 /g;
    $line =~ s/ +($)//;
  }
  $_ = $line;
}
continue {
  print; # this prints to original filename
}
report($old_argv, $saw_0a, $saw_0d, $saw_0d0a);
select(STDOUT);
