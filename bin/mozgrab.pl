#! /bin/sh
eval '(exit $?0)' && eval 'PERL_BADLANG=x;PATH="$PATH:.";export PERL_BADLANG\
;exec perl -x -S -- "$0" ${1+"$@"};#'if 0;eval 'setenv PERL_BADLANG x\
;setenv PATH "$PATH":.;exec perl -x -S -- "$0" $argv:q;#'.q
#!perl -w
+push@INC,'.';$0=~/(.*)/s;do(index($1,"/")<0?"./$1":$1);die$@if$@__END__+if 0
;#Don't touch/remove lines 1--7: http://www.inf.bme.hu/~pts/Magic.Perl.Header
#
# mozgrab.pl -- grab a web page, as rendered by Mozilla (on UNIX X11)
# by pts@fazekas.hu at Thu Dec 30 17:24:55 CET 2004
#
# Dat: when a missing file:///, there is an alert() first, then mozgrab.pl
#      fails
# Dat: no need for XMapWindow etc: move+raise is just fine, even if the
#      original Mozilla is iconfied
# Dat: concurrent run of this script not possible (wm_delete_prev_pages() etc.)
# Dat: tested on Debian Woody, with Mozilla-1.6
# Dat: problem when -remote to a Mozilla not running on localhost
# Dat: we don't stop Mozilla not even if we started it
# Dat: doesn't work if the page sets its (partial) background color in a tricky way
# Imp: document UniversalBrowserRead
# Imp: does `mozilla --sync' make us good?
# Imp: innerWidth=?, outerWidth=? +-1 in grabbing
# Imp: communicate with onresize events, don't need high window
# Imp: sending event to an unclosed window
# Imp: Mozilla sometimes fails to render the last page properly
use integer;
use strict;

# <Configuration>
#** Must be a single command, spaces (and args) not allowed!
my $mozilla_cmd="mozilla";
#** @example ("mozilla-1.6","-remote")
my @mozilla_remote_cmd;
#** @example ("/usr/X11R6/lib")
my @x_lib_dirs;
#** @example ("/usr/X11R6/include/X11")
my @x_include_dirs;
my $mozilla_file;
my $mozilla_prog_test=sub { $_[0]=~m@/(?:mozilla|firefox|galeon)(?:-bin)?\Z(?!\n)@ };
my $mozilla_start_secs=30;
my $grab_width=1024; # width of the grab window
#** No
my $grab_height=100;
#** Dat: may contain only [-.\w\/]
my $tmpdir="/tmp";
#my $url="file:///tmp/hello.html"; # !! ', ", \ quote
my $url="http://www.freshmeat.net/";
my $window_open_flags='alwaysRaised=yes,dependent=no,directories=no,hotkeys=no,location=no,menubar=no,resizable=no,scrollbars=no,status=no,titlebar=no,toolbar=no';
##** Used for detecting bottom of the page
# my $uniform_color="#ffffff";
my @CC=qw(gcc);
my @CFLAGS=qw(-s -O2 -W -Wall);
my $page_load_secs=60;
my $outfile="mozgrab.ppm";
my $bufsize=4096;
#** Dat: needed for http://www.freshmeat.net/
my $initial_resize_secs=5;
my $subsequent_resize_secs=2;

# </Configuration>

if (!@ARGV || $ARGV[0]eq'--help') {
  die "Usage: $0: <option> [...]
Options:
--url=<url>
--outfile=<filename>
--grab-width=<pixels>
";
}

{ my $I=0;
  while ($I<@ARGV) {
    if ($ARGV[$I] eq '-') { last }
    elsif ($ARGV[$I] eq '--') { $I++; last }
    elsif (substr($ARGV[$I],0,6)eq'--url=') { $url=substr($ARGV[$I++],6) }
    elsif (substr($ARGV[$I],0,10)eq'--outfile=') { $outfile=substr($ARGV[$I++],10) }
    elsif ($ARGV[$I]=~/\A--grab-width=(\d+)\Z(?!\n)/ and $1>0) { $grab_width=$1+0; $I++ }
    else { die "$0: unknown option: $ARGV[$I]\n" }
  }
  splice @ARGV, 0, $I
}
die "$0: arg list not empty after options\n" if @ARGV;
die "$0: missing --url=\n" if !defined$url;
die "$0: missing --outfile=\n" if !defined$outfile;
die "$0: bad --url= syntax, need something like http://... or file:///...\n" if
  $url!~/\Ajavascript:/ and ($url!~/\A\w+:\/\// or $url=~/\Afile:\/\/(?!\/)/);

sub shq($) {
  my $S=$_[0];
  return $S if $S!~/[^-.\w\/]/;
  $S=~s@'@'\\''@g;
  "'$S'"
}

#* @return absolute or relative filename, with `/'
sub find_on_path($) {
  my $prog=$_[0];
  my @path=split(/:+/,$ENV{PATH});
  for my $dir (@path) {
    next if 0==length$dir;
    ## print "$dir\n";
    return "$dir/$prog" if (-f"$dir/$prog"); # Dat: same for execlp() no check for executable bit
  }
  undef
}

sub find_mozilla_file() {
  if (!defined$mozilla_file) {
    $mozilla_file=find_on_path($mozilla_cmd);
    die "$0: mozilla command not found: $mozilla_cmd\n" if !defined $mozilla_file;
  }
  $mozilla_file
}

sub stripshslashes($$) {
  # Imp: better
  my($S,$H)=@_;
  $S=~s@\\(.)|\$([A-Za-z]\w*)@
    defined $1 ? $1 : defined $H->{$2} ? $H->{$2} : ""
  @sge;
  $S
}

sub find_mozilla_remote_cmd() {
  if (!@mozilla_remote_cmd) {
    my $S;
    ##die find_mozilla_file();
    die unless open F, "< ".find_mozilla_file();
    die unless 2==read(F, $S, 2);
    if ($S eq "#!") { # Dat: debian system w/ stupid shell script
      my %H=%ENV;
      while (defined($S=<F>)) {
        if ($S=~/^([A-Z]\w*)="(.*)"\s*$/) {
          my $K=$1;
          $H{$K}=stripshslashes($2,\%H);
        }
      }
      # Dat: MOZ_PROGRAM="/usr/lib/mozilla/mozilla-bin"
      # Dat: MOZ_PROGRAM="$MOZ_DIST_LIB/mozilla-xremote-client"
      # Dat: MOZ_CLIENT_PROGRAM="/usr/lib/mozilla/mozilla-xremote-client"
      if (defined $H{MOZ_CLIENT_PROGRAM}) {
        @mozilla_remote_cmd=($H{MOZ_CLIENT_PROGRAM});
      } elsif (defined $H{MOZ_PROGRAM}) {
        @mozilla_remote_cmd=($H{MOZ_PROGRAM},'-remote');
      }
    }
    # Imp: do we have to set LD_LIBRARY_PATH?
    @mozilla_remote_cmd=($mozilla_cmd,'-remote') if !@mozilla_remote_cmd;
    die "$0: couldn't find mozilla remote command\n" if !@mozilla_remote_cmd;
  }
  @mozilla_remote_cmd
}

sub is_mozilla_running() {
  system find_mozilla_remote_cmd(), 'ping()';
  die "$0: cannot ping mozilla (system): $!\n" if $!;
  if ($?==0) { return 1 }
  elsif ($?==0x200) { return 0 }
  die "$0: cannot ping mozilla (exit): $?\n";
}

sub is_my_local_mozilla_running() {
  # Imp: use WM_CLIENT_MACHINE(STRING) = "winter"
  die unless open P, "ps x|"; # Dat: my processes, even w/o controlling tty
  my $S;
  my $ret=0;
  while (defined($S=<P>)) {
    # Dat: 790 tty1     S      0:00 /usr/lib/mozilla/mozilla-bin
    if ($S=~/^ *\S+\s+\S+\s+\S+\s+\S+\s+(.*)/) {
      $ret=1 if $mozilla_prog_test->($1);
    }
  }
  die "$0: ps(1) failed, status=$?\n" unless close P;
  $ret
}

sub start_mozilla() {
  print "Starting mozilla: ";
  print STDERR "warning: space in Mozilla command: $mozilla_cmd\n" if
    $mozilla_cmd=~/\s/;
  system shq($mozilla_cmd)." & disown"; # Dat: force background
  # Dat: the Debian `mozilla' script would start Netscape 4.77 (!) if we gave
  #      an arg to $mozilla_cmd here!
  # Imp: check profile problems etc.
  # Imp: early failure by testing `ps' or stderr etc.
  my $C=$mozilla_start_secs;
  while ($C>0 and !is_mozilla_running()) {
    sleep 1;
    print '.';
    $C--;
  }
  print "\n";
}

sub find_x_lib_dirs() {
  if (!@x_lib_dirs) {
    my $xwi=find_on_path('xwininfo');
    die "$0: xwininfo: not found on \$PATH\n" if !defined$xwi;
    die unless open P, "ldd ".shq($xwi)."|";
    my $S;
    my $dir;
    while (defined($S=<P>)) {
      if ($S=~/^[ \t]*libX11[.].*? =>\s+(\/[^\/\s]+\/\S+)/) {
        # Imp: push all?
        $dir=$1; die unless $dir=~s@/[^/]+\Z@@;
      }
    }
    die unless close P;
    die "$0: ldd xwininfo didn't contain library path\n" if !defined$dir;
    @x_lib_dirs=($dir);
  }
  @x_lib_dirs
}

sub find_x_include_dirs() {
  if (!@x_include_dirs) {
    for my $dir (find_x_lib_dirs()) {
      my $dir2=$dir;
      if ($dir2=~s@/lib\Z(?!\n)@/include/X11@ and -f "$dir2/Xutil.h") {
        @x_include_dirs=($dir2); last
      }
    }
  }
  if (!@x_include_dirs) {
    for my $dir2 (qw(/usr/include/X11 /usr/X11R6/include/X11)) {
      if (-f "$dir2/Xutil.h") {
        @x_include_dirs=($dir2); last
      }
    }
  }
  @x_include_dirs
}

my @files_to_unlink;
sub unlink_files() { unlink @files_to_unlink; @files_to_unlink=() }
END { unlink_files() }
$SIG{INT }=sub { unlink_files(); exit 20 };
$SIG{TERM}=sub { unlink_files(); exit 21 };
$SIG{HUP }=sub { unlink_files(); exit 22 };
$SIG{QUIT}=sub { unlink_files(); exit 23 };

sub compile_xcmd() {
  die unless open F, "> $tmpdir/xcmd.c";
  push @files_to_unlink, "$tmpdir/xcmd.c";
  die unless print F <<'END';
#define DUMMY \
  set -ex; \
  gcc -O2 -W -Wall -ansi -pedantic -L/usr/X11R6/lib -L/usr/local/lib -lX11 xcmd.c -o xcmd; \
  exit 0
/*
 * xcmd.c -- do simple commands with X11 windows
 * by pts@fazekas.hu at Thu Dec 30 16:13:48 CET 2004
 * This is part of mozgrab.pl, need sync with original xcmd.c
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 */

#if OBJDEP
#  warning PROVIDES: xmove_main
#endif

/* #include "config2.h" */
/* #include "ylib.h" */

#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <stdio.h> /* printf() */
#include <string.h> /* strcmp() */
#include <unistd.h> /* write() */

typedef char bool_;

/**
 * @param needle may not be '\0'-terminated
 *   like strstr(), but slow and respects needle_len. No advanced preconditioning
 *   (like B--More) or such.
 */
static char* strfixstr(char *s1, char *needle, int needle_len) {
  char *p;
  if (!needle_len) return (char *) s1;
  while (NULL!=(p=strchr(s1, needle[0]))) {
    if (0==strncmp(p, needle, needle_len)) return p;
    p++;
  }
  return NULL;
}

/** similar to fpatmatch() @param glob may contain ? and * */
static bool_ strglobmatch(char *str, char *glob) {
  /* Test: strglobmatch("almamxyz","?lmam*??") */
  int min;
  while (glob[0]!='\0') {
    if (glob[0]!='*') {
      if ((glob[0]=='?') ? (str[0]=='\0') : (str[0]!=glob[0])) return 0;
      glob++; str++;
    } else { /* a greedy search is adequate here */
      min=0;
      while (glob[0]=='*' || glob[0]=='?') min+= *glob++=='?';
      while (min--!=0) if (*str++=='\0') return 0;
      min=0; while (glob[0]!='*' && glob[0]!='?' && glob[0]!='\0') { glob++; min++; }
      if (min==0) return 1; /* glob ends with star */
      if (NULL==(str=strfixstr(str, glob-min, min))) return 0;
      str+=min;
    }
  }
  return str[0]=='\0';
}


/* --- */

Display *dpy;
char const *argv0;
/** Dat: we don't want XAtom.h -- we want to be compatible */
Atom xa_WM_STATE=None, xa_WM_NAME=None, xa_STRING=None, xa_MOZILLA_VERSION,
  xa_WM_PROTOCOLS=None, xa_WM_DELETE_WINDOW=None;

static bool_ has_wm_state(Window winID) {
  Atom ret_type;
  int ret_format;
  unsigned long ret_nitems, ret_bytes_after;
  unsigned char *ret_data;
  if (xa_WM_STATE==None) xa_WM_STATE=XInternAtom(dpy, "WM_STATE", False);
  if (XGetWindowProperty(dpy, winID, xa_WM_STATE, 0,
   32, /* Imp: why? */
   False, xa_WM_STATE, &ret_type, &ret_format, &ret_nitems, &ret_bytes_after, &ret_data)==Success && ret_type) {
    XFree(ret_data);
    return True;
  }
  return False;
}

#define window_title(winID) get_string_prop(winID,"WM_NAME")

/** @return NULL or string, must be freed with XFree() */
static char *get_string_prop(Window winID, char *prop_name) {
  Atom ret_type, xa;
  int ret_format;
  unsigned long ret_nitems, ret_bytes_after;
  unsigned char *ret_data;
  if (0==strcmp(prop_name,"WM_NAME")) {
    if (xa_WM_NAME==None) xa_WM_NAME=XInternAtom(dpy, "WM_NAME", False);
    xa=xa_WM_NAME;
  } else {
    xa=XInternAtom(dpy, prop_name, /*only_if_exists:*/False);
  }
  if (xa_STRING ==None) xa_STRING =XInternAtom(dpy, "STRING",  False);
  if (XGetWindowProperty(dpy, winID, xa, 0,
   65535, /* Dat: max 65535 bytes, please */
   False, xa_STRING, &ret_type, &ret_format, &ret_nitems, &ret_bytes_after, &ret_data)==Success && ret_type) {
    /* Dat: XGetProperty appends '\0'. Fine. */
    if (ret_bytes_after!=0) {
      XFree(ret_data);
    }
    return (char*)ret_data;
  }
  return (char*)NULL;
}

#if 0
static bool_ has_string_prop(Window winID, char *prop_name) {
  char *s=get_string_prop(winID, prop_name);
  if (s!=NULL) { XFree(s); return True; }
  return False;
}
#endif

#if 0
/** Lists windows descending from winId, having titles, recursively */
static void list_titles(Window winID) {
  Window rootwin2, parentwinID;
  Window *children, *p, *pend;
  unsigned nchildren;
  char *title;
  if (has_wm_state(winID) &&
    /* SUXX: Firefox doesn't expose this or others has_string_prop(winID, "_MOZILLA_USER") && */
    NULL!=(title=get_string_prop(winID,"WM_NAME"))) {
    /* Imp: disable FvwmButtons etc. */
    printf("title of 0x%lx is (%s)\n", (unsigned long)winID, title); 
    XFree(title);
  }
  if (XQueryTree(dpy, winID, &rootwin2, &parentwinID, &children, &nchildren)) {
    for (pend=(p=children)+nchildren; p!=pend; p++) list_titles(*p);
    if (children!=NULL) XFree(children);
  }
}
#endif

/** Lists windows descending from winId, having titles, recursively */
static bool_ print_find_with_title(Window winID, char *glob) {
  Window rootwin2, parentwinID;
  Window *children, *p, *pend;
  unsigned nchildren;
  char *title;
  if (has_wm_state(winID) &&
    /* SUXX: Firefox doesn't expose this or others has_string_prop(winID, "_MOZILLA_USER") && */
    NULL!=(title=get_string_prop(winID,"WM_NAME"))) {
    /* Imp: disable FvwmButtons etc. */
    /* printf("title of 0x%lx is (%s)\n", (unsigned long)winID, title);  */
    if (strglobmatch(title, glob)) {
      printf("0x%lx\n%s\n", (unsigned long)winID, title);
      return True;
    }
    XFree(title);
  }
  if (XQueryTree(dpy, winID, &rootwin2, &parentwinID, &children, &nchildren)) {
    for (pend=(p=children)+nchildren; p!=pend; p++) {
      if (print_find_with_title(*p, glob)) {
        XFree(children);
        return True;
      }
    }
    if (children!=NULL) XFree(children);
  }
  return False;
}

#if 0
    printf("has_wm_state=%d\n", has_wm_state(winID));
    { char *title=get_string_prop(winID,"WM_NAME");
      printf("title=(%s)\n", title);
      if (title!=NULL) XFree(title);
    }
#endif

/** Graceful delete, through Window Manager protocol */
static void delete_window(Window winID) {
  XClientMessageEvent ev;
  if (xa_WM_PROTOCOLS == None) xa_WM_PROTOCOLS = XInternAtom(dpy, "WM_PROTOCOLS", False);
  if (xa_WM_DELETE_WINDOW == None) xa_WM_DELETE_WINDOW= XInternAtom(dpy, "WM_DELETE_WINDOW", False);
  ev.type = ClientMessage;
  ev.window = winID;
  ev.message_type = xa_WM_PROTOCOLS;
  ev.format = 32;
  ev.data.l[0] = xa_WM_DELETE_WINDOW;
  ev.data.l[1] = /*(Time)*/CurrentTime;
  XSendEvent (dpy, winID, False, 0L, (XEvent *) &ev);
}

int main(int argc, char **argv) {
  int scr;
  Window rootwin;
  XVisualInfo vinfo;
  Colormap colormap;
  unsigned long black_pixel, white_pixel;
  int doitp=1, ret=0;
  unsigned long winID=None; /* large enough */

  (void)argc; (void)argv;
  dpy=XOpenDisplay(NULL);
  scr=DefaultScreen(dpy);
  rootwin=RootWindow(dpy,scr);
  vinfo.depth=DefaultDepth(dpy,scr);
  vinfo.visual=DefaultVisual(dpy,scr);
  colormap=DefaultColormap(dpy,scr);
  black_pixel=BlackPixel(dpy,scr);
  white_pixel=WhitePixel(dpy,scr);
  #if 0
    /* Atom wm_protocols; */
    wm_protocols = XInternAtom(dpy, "WM_PROTOCOLS", False);
    wm_delete_window = XInternAtom(dpy, "WM_DELETE_WINDOW", False);
    sel_prisec[1] = XInternAtom(dpy, "PRIMARY", False);
    sel_prisec[0] = XInternAtom(dpy, "SECONDARY", False);
    ty_string = XInternAtom(dpy, "STRING", False);
  #endif
  
  XKillClient(dpy, AllTemporary);
  
  argv0=*argv++;
  if (*argv==NULL || 0==strcmp(argv[0],"--help")) { /* no args, help */
    printf("Usage: %s {-N|-all|-id 0xWINID|-find|-root} <command>\nCommands are:\n  move <x> <y>\n  resize <width> <height>\n  find <glob>\n  id\n  raise\n  destroy\n  get_size\n  expose <x> <y> <width> <height>\n  wm_delete\n  kill\n  map\n", argv0);
    return 2;
  }
  while (*argv!=NULL) {
    if (0==strcmp(argv[0], "-N")) {
      argv++; doitp=0;
    } else if (0==strcmp(argv[0], "-all")) {
      argv++; doitp=1;
    } else if (0==strcmp(argv[0], "-find")) {
      argv++;
    } else if (0==strcmp(argv[0], "-root")) {
      argv++; winID=rootwin;
    } else if (argv[1]!=0 && 0==strcmp(argv[0], "-id") && 1==sscanf(argv[1],"%li",&winID)) {
      if (winID==0) winID=rootwin;
      argv+=2;
    } else if (0==strcmp(argv[0], "--")) {
      argv++;
      break;
    } else if (argv[0][0]!='-' || argv[0][1]=='\0') {
      break;
    } else {
      printf("%s: unknown option: %s\n", argv0, argv[0]);
      return 3;
    }
  }
  
  if (winID==None) {
    fprintf(stderr, "%s: window not specified\n", argv0);
    return 4;
  } else if (argv[0]==NULL) {
    fprintf(stderr, "%s: missing command\n", argv0);
    return 5;
  } else if (0==strcmp(argv[0],"find")) {
    if (argv[1]==NULL || argv[2]!=NULL) { wac:
      fprintf(stderr, "%s: wrong arg count for command: %s\n", argv0, argv[0]);
      return 6;
    }
    ret=!print_find_with_title(winID, argv[1]);
  } else if (0==strcmp(argv[0],"move") || 0==strcmp(argv[0],"resize")) {
    int x, y;
    if (argv[1]==NULL || argv[2]==NULL || argv[3]!=NULL) goto wac;
    if (1!=sscanf(argv[1],"%i",&x)) { /* Imp: verify trailing */
      fprintf(stderr, "%s: could not parse int <x>: %s\n", argv0, argv[1]);
      return 6;
    }
    if (1!=sscanf(argv[2],"%i",&y)) {
      fprintf(stderr, "%s: could not parse int <y>: %s\n", argv0, argv[2]);
      return 7;
    }
    if (0==strcmp(argv[0],"move")) XMoveWindow  (dpy, winID, x, y); /* Dat: may be negative */
                              else XResizeWindow(dpy, winID, x, y);
  } else if (0==strcmp(argv[0],"expose")) {
    int x, y, width, height;
    XEvent event;
    XExposeEvent *e;
    if (argv[1]==NULL || argv[2]==NULL || argv[3]==NULL || argv[4]==NULL || argv[5]!=NULL) goto wac;
    if (1!=sscanf(argv[1],"%i",&x)) { /* Imp: verify trailing */
      fprintf(stderr, "%s: could not parse int <x>: %s\n", argv0, argv[1]);
      return 6;
    }
    if (1!=sscanf(argv[2],"%i",&y)) {
      fprintf(stderr, "%s: could not parse int <y>: %s\n", argv0, argv[2]);
      return 7;
    }
    if (1!=sscanf(argv[3],"%i",&width)) {
      fprintf(stderr, "%s: could not parse int <width>: %s\n", argv0, argv[3]);
      return 6;
    }
    if (1!=sscanf(argv[4],"%i",&height)) {
      fprintf(stderr, "%s: could not parse int <height>: %s\n", argv0, argv[4]);
      return 7;
    }
    /* if( windowAttr.map_state == IsViewable ) */
    e = (XExposeEvent *)(&event);		/* Send message to window to redraw */
    e->type = Expose;
    e->send_event = True;
    e->display = dpy;
    e->window = winID;
    e->x = x;
    e->y = y;
    e->width = width;
    e->height = height;
#if 0
    XClearWindow(dpy, winID); /* Dat: no effect on windows w/o bg */
    printf("Cleared\n");
#endif
    while (1) XSendEvent( dpy, winID, True, ExposureMask, &event );
    XFlush( dpy );
  } else if (0==strcmp(argv[0],"id")) {
    if (argv[1]!=NULL) goto wac;
    printf("0x%lx\n", (unsigned long)winID);
  } else if (0==strcmp(argv[0],"raise")) {
    if (argv[1]!=NULL) goto wac;
    XRaiseWindow(dpy, winID);
  } else if (0==strcmp(argv[0],"destroy")) {
    if (argv[1]!=NULL) goto wac;
    XDestroyWindow(dpy, winID); /* Dat: might be dangerous */
  } else if (0==strcmp(argv[0],"kill")) {
    if (argv[1]!=NULL) goto wac;
    XKillClient(dpy, (XID)winID);
  } else if (0==strcmp(argv[0],"map")) {
    if (argv[1]!=NULL) goto wac;
    XMapWindow(dpy, winID);
  } else if (0==strcmp(argv[0],"wm_delete")) {
    if (argv[1]!=NULL) goto wac;
    delete_window(winID);
  } else if (0==strcmp(argv[0],"get_size")) {
    XWindowAttributes wa;
    if (argv[1]!=NULL) goto wac;
    if (!XGetWindowAttributes(dpy, winID, &wa)) {
      fprintf(stderr, "%s: error getting window attributes\n", argv0);
      return 9;
    }
    printf("%d %d\n", wa.width, wa.height); /* Dat: may be negative?? */
  } else {
    fprintf(stderr, "%s: unknown command: %s\n", argv0, argv[0]);
    return 8;
  }
  XSync(dpy, True); /* Dat: print pending errors */
  return ret;
}
END
  die unless close F;
  my @cmd=(@CC,@CFLAGS,
    (map{"-I$_"}find_x_include_dirs()), "$tmpdir/xcmd.c",
    (map{"-L$_"}find_x_lib_dirs()), '-lX11',  "-o",'xcmd');
  print "Compiling xcmd: @cmd\n";
  die "$0: compilation failed, status=$?\n" if 0!=system @cmd;
  # die 42;
}

sub no_xcmd() {
  my $S=readpipe "./xcmd -root id 2>&1";
  $S="./xcmd: $!\n" if !defined $S;
  chomp $S;
  $S=~/^0x[0-9a-fA-F]+$/ ? '' : $S
}

#** @param $_[0] window title glob (* and ?)
#** @return () ($hexwinid,$title)
sub get_window_info($) {
  my $S=readpipe("./xcmd -root find ".shq($_[0])." 2>&1");
  die "\n$0: error starting xcmd: $!\n" if !defined $S; # Dat: usually not happens
  $S=~/^(0x[0-9a-fA-F]+)\n(.*)\n\Z(?!\n)/s ? ($1,$2) : ()
}

sub wm_delete_prev_pages() {
  my($winID,$title);
  my %H;
  print "Killing previously grabbed pages: ";
  while (1) {
    ($winID,$title)=get_window_info("*([onload1 ?*x?* *])*");
    last if !defined $title;
    wm_delete_window($winID);
    if (exists $H{winID}) { print "."; sleep 1; }
    $H{winID}=1
  }
  my $C=scalar keys%H;
  print " ($C)\n";
}
  

#** @return ($winID,$title,$width,$height)
#** Dat: $width is $grab_width, height is real height (in pixels) occupied by
#**      the page
sub wait_page_load($) {
  my $rand=$_[0];
  my($winID,$title);
  my $C=$page_load_secs;
  print "Waiting for the page to load: ";
  while (1) {
    # Dat: we find our window because it has $rand it its title (2^{-31} chance)
    ($winID,$title)=get_window_info("*([onload1 ?*x?* $rand])*");
    last if defined $title;
    sleep 1; print "."; $C--;
  }
  print "\n";
  die "$0: timed out waiting for page to load\n" if !defined $title;
  print "Rendered X11 window ID: $winID\n";
  print "Rendered page info title: $title\n";
  die "$0: syntax error in title found\n" unless
    $title=~/\(\[onload1 (\d+)x(\d+) \Q$rand\E\]\)/;
  if ($1==0 and $2==0) {
    # Dat: this happens e.g on nameserver resolve error
    wm_delete_window($winID);
    die "$0: web page failed to load (is the URL correct?)\n";
  }
  # vvv Dat: error if Mozilla fails to load...
  die if $1<1 or $2<1;
  ($winID,$title,$1+0,$2+0)
}

#** @return ($width,$height) of the root window
sub get_root_dimensions() {
  my $S=readpipe("./xcmd -root get_size 2>&1");
  die "\n$0: error starting xcmd: $!\n" if !defined $S; # Dat: usually not happens
  die "$0: cannot get dimensions of the root window, got ($S)\n" unless
    $S=~/^(\d+) (\d+)$/;
  die if $1<1 or $2<1;
  ($1+0,$2+0);
}

# Imp: not so many sub{}s
sub move_window($$$) {
  my($winID,$x,$y)=($_[0],$_[1]+0,$_[2]+0);
  my $S=readpipe("./xcmd -id ".shq($winID)." move $x $y 2>&1");
  die "\n$0: error starting xcmd: $!\n" if !defined $S; # Dat: usually not happens
  die "$0: cannot move window, got ($S)\n" if 0!=length$S;
}

sub expose_window($$$$$) {
  my($winID,$x,$y,$width,$height)=($_[0],$_[1]+0,$_[2]+0,$_[3]+0,$_[4]+0);
  my $S=readpipe("./xcmd -id ".shq($winID)." expose $x $y $width $height 2>&1");
  die "\n$0: error starting xcmd: $!\n" if !defined $S; # Dat: usually not happens
  die "$0: cannot move window, got ($S)\n" if 0!=length$S;
}

sub resize_window($$$) {
  my($winID,$x,$y)=($_[0],$_[1]+0,$_[2]+0);
  my $S=readpipe("./xcmd -id ".shq($winID)." resize $x $y 2>&1");
  die "\n$0: error starting xcmd: $!\n" if !defined $S; # Dat: usually not happens
  die "$0: cannot move window, got ($S)\n" if 0!=length$S;
}

sub raise_window($) {
  my($winID)=@_;
  my $S=readpipe("./xcmd -id ".shq($winID)." raise 2>&1");
  die "\n$0: error starting xcmd: $!\n" if !defined $S; # Dat: usually not happens
  die "$0: cannot move window, got ($S)\n" if 0!=length$S;
}

sub wm_delete_window($) {
  my($winID)=@_;
  my $S=readpipe("./xcmd -id ".shq($winID)." wm_delete 2>&1");
  die "\n$0: error starting xcmd: $!\n" if !defined $S; # Dat: usually not happens
  die "$0: cannot move window, got ($S)\n" if 0!=length$S;
}

select(STDERR); $|=1;
select(STDOUT); $|=1;

print "Mozilla command: $mozilla_cmd\n";
find_mozilla_remote_cmd();
print "Mozilla remote command: @mozilla_remote_cmd\n";
exit;
my $is_running;
if (is_mozilla_running()) {
  print "Mozilla is running. Good.\n";
  # Imp: check for Mozilla on local 
} else {
  start_mozilla();
}
die "$0: Mozilla is still not running!\n" if !is_mozilla_running();
if (!is_my_local_mozilla_running()) {
  die "$0: a local Mozilla is not running on behalf of this user (UID=$<)\n";
}
print "A Mozilla is running locally. I hope this is the one we need.\n";

{ my $no_xcmd=no_xcmd();
  if (0==length($no_xcmd)) {
    print "xcmd seems to work. Good.\n";
  } else {
    print "X11 library directories: @{[find_x_lib_dirs()]}\n";
    print "X11 include directories: @{[find_x_include_dirs()]}\n";
    compile_xcmd();
    die "$0: cannot make xcmd work, got ($no_xcmd)\n" if
      0!=length($no_xcmd=no_xcmd());
  }
}

my $rand=rand(); $rand=~s@\A0[.]@r@;
print "Random window ID will be $rand\n";

my $tmpfn="$tmpdir/$rand.html";
print "Temporary main HTML is $tmpfn\n";
die unless open F, "> $tmpfn";
push @files_to_unlink, $tmpfn;
# Dat: a long page (total height) 30000 really slows X11 down (try to move the mouse) --
#      but this is the only way we can grab multiple pages
# Dat: we don't need <IFRAME MARGINWIDTH=0 MARGINHEIGHT=0, will respect
#      <BODY of loaded document
# Dat: there is no document.style
# Dat: no need to set tip.document.background=""; tip.document.bgColor="#$uniform_color";
#      because we can query tip.document.height directly
# Dat: it seems to be impossible to enlarge the IFRAME vertically, so we make
#      it larger than the X11 maximum (32767) -- this doesn't consume much 
#      memory. tip.innerHeight=..., tip.height=..., tip.body.height=...
#      tip.resizeTo(?,?) etc. are all quite useless. I don't get it...
#      However, window.onresize=function(e) { }; is fine.
# Dat: we do _not_ want IFRAME ALIGN=top, so scrollHeight works at last
# SUXX: this might cause problems, number too large: <BODY MARGINHEIGHT=25000 MARGINWIDTH=3>
# Dat: we need <IFRAME HEIGHT=1 below there to get tip.document.documentElement.scrollHeight calculated properly
die unless print F qq~
<BODY MARGINWIDTH=0 MARGINHEIGHT=0>
<IFRAME SRC="$url" ID=tid NAME=tip FRAMEBORDER=0 WIDTH=$grab_width HEIGHT=1 SCROLLING=no>
</IFRAME>
<SCRIPT>
//function f(){}
// Dat: no effect: window.onerror=function() { alert("error loading web page"); };
window.onload=function() { // Dat: waits for the <IFRAME to load
  // document.bgColor="#ff0000"; // Dat: no effect, completely overridden by tip -- seems to be inheritable(!)
  // tip.document.bgColor="#ffffff";
  // tip.document.body.scrollTop=300;
  // Dat: .offsetWidth and .offsetHeight would be also OK
  var ht,wd,de;
  try { de=tip.document.documentElement; }
  catch (e) { netscape.security.PrivilegeManager.enablePrivilege("UniversalBrowserRead"); de=tip.document.documentElement; }
  // ^^^ Dat: this is needed for viewing a http:// web page from our file://
  var ht=de.scrollHeight,wd=de.scrollWidth;
  window.document.getElementById('tid').style.height=''+ht+'px'; // SUXX: took 30 minutes to figure out; doesn't work with NAME=, needs ID=
  window.document.title="([onload1 "+wd+"x"+ht+" $rand])";
//  window.open('javascript:"<head><title>([onload2 '+tip.document.height+' $rand])</title></head>This is to inform the grabber that the document is loaded."',
//    'onload','$window_open_flags,height=30,width=500');
};
</SCRIPT>
~;
die unless close F;

my $reffn="$tmpdir/r$rand.html";
# Dat: we need another file because Mozilla doesn't allow openURL(javascript:...file://
print "Temporary referer HTML is $reffn\n";
die unless open F, "> $reffn";
push @files_to_unlink, $reffn;
die unless print F qq~<SCRIPT>
window.open('file://$tmpfn','t4','$window_open_flags,height=$grab_height,width=$grab_width');
</SCRIPT>
You can close this tab, has been used for grabbing, but it is no longer in use.
~;
die unless close F;
# Dat: we need another file because Mozilla doesn't allow openURL(javascript:...file://
wm_delete_prev_pages();

print "* If you want to have the web page grabbed, please don't touch the\n";
print "  mouse or the keyboard. Press Ctrl-<C> in this window to abort.\n";
print "  (You will have to close the extra Mozilla windows by hand.)\n";
print "Will show URL $url\n";
print "Opening $reffn in new tab.\n";
die "$0: mozilla_remote_cmd failed, status=$?\n" if
  0!=system @mozilla_remote_cmd, "openURL(file://$reffn,new-tab)";

my ($winID,$title,$width,$height)=wait_page_load($rand);
print "Rendered page dimensions: $width x $height\n";
if ($height>32000) {
  $height=32000; # Dat: X11 maximum is 32768 -- but X server becomes quite slow soon
  print "Adjusted page dimensions: $width x $height\n";
}
my ($root_width,$root_height)=get_root_dimensions();
print "Root window dimensions: $root_width x $root_height\n";
die "$0: root window too narrow $root_width < $grab_width\n" if
  $root_width<$grab_width;

move_window($winID,0,0);
resize_window($winID,$width,$height);
raise_window($winID);
# vvv Dat: puts Mozilla to infinite loop
#expose_window($winID,0,0,0, $root_height < $height ? $root_height : $height); # Imp: sleep?

# !! properly wait for resize event to be handled etc.
print "Waiting for initial resize\n";
sleep $initial_resize_secs;
print "Dumping to file $outfile\n";
die unless open OUT, "> $outfile";
printf OUT "P6 $width $height 255\n";
my $height_left=$height;
die if $height_left<1;
my $height_step;

while (1) {
  $height_step=$root_height < $height_left ? $root_height : $height_left;
  # Dat: pnmdepth 255 <t.pbm >tt.ppm; pnmdepth: promoting from PBM to PGM
  die unless open P, "xwd -id ".shq($winID)." | xwdtopnm | pnmdepth 255 |";
  # ^^^ Dat: pnmdepth emits PGM or PPM
  my $line1=<P>;
  die unless defined $line1 and ($line1 eq "P5\n" or $line1 eq "P6\n");
  my $line2=<P>;
  die unless defined $line2 and $line2=~/^(\d+) (\d+)/;
  my($got_width,$got_height)=($1+0,$2+0);
  die "$0: width mismatch: $got_width != $width" if $width!=$got_width;
  die "$0: height mismatch: $got_height != $height_step" if $height_step!=$got_height;
  my $line3=<P>;
  die unless defined $line3 and $line3 eq "255\n";
  print "Adding $got_height rasterlines...\n";
  my($S,$need);
  if ($line1 eq "P5\n") { # Dat: PGM file, convert to PPM
    my $left=$got_width*$got_height;
    my($T,$I);
    while ($left>0) {
      $need=$left < $bufsize ? $left : $bufsize;
      die unless $need=read P, $S, $need; # Dat: truncates $S
      $T="";
      for ($I=0;$I<length$S;) { $T.=substr($S,$I,1).substr($S,$I,1).substr($S,$I,1) }
      die unless print OUT $T;
      $left-=$need;
    }
  } else { # copy PPM
    my $left=$got_width*$got_height*3;
    while ($left>0) {
      $need=$left < $bufsize ? $left : $bufsize;
      die unless $need=read P, $S, $need; # Dat: truncates $S
      die unless print OUT $S;
      $left-=$need;
    }
  }
  die "$0: EOF expected in PNM\n" unless 0==read P, $S, 1;
  die unless close P;
  last if ($height_left-=$got_height)==0;
  move_window($winID,0,$height_left-$height); # Dat: y offset is negative!
  raise_window($winID); # Dat: to make sure
  #  expose_window($winID,0,$height-$height_left,$width, $root_height < $height_left ? $root_height : $height_left); # Dat: to make sure
  print "Waiting for resize...\n";
  sleep $subsequent_resize_secs;
} # WHILE
die unless close OUT;

print "Closing window.\n";
wm_delete_window($winID);
print "* Please close the tab ``You can close this tab'' in the Mozilla window.\n";
print "Done grabbing to file $outfile\n";

__END__
