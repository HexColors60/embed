0 ok! ( Turn off 'ok' prompt )
\ | Project   | A Small Forth VM/Implementation |
\ | --------- | ------------------------------- |
\ | Author    | Richard James Howe              |
\ | Copyright | 2017 Richard James Howe         |
\ | License   | MIT                             |
\ | Email     | howe.r.j.89@gmail.com           |
 
\ ## A Meta-compiler, an implementation of eForth and a tutorial on both.
\ Project site: <https://github.com/howerj/embed>

\ # Introduction

\ @todo Complete the introduction
\ - Describe where the Forth came from (from a VHDL CPU project, eForth, ...)
\ - Philosophy of Forth
\   - Simplicity, Factoring, analyzing the problem from all angles, ...
\   - What Forth is good for, and what it is not.
\ - What a meta compiler is
\ - Purpose of this document
\ - A little bit about Forth, a simple introduction
\ - How Vocabularies work
\ - Stack comments, also standardize stack comments
\ - Conventions within Forth, Forth blocks, naming of words (for example
\   using '@' or '!' within words).
\ - Design tradeoffs and constraints
\   - For example: having a separate string storage area
\   - Limitations of the Virtual Machines code space
\   - Compiler security (depth checking, compile-only words, ... )
\   Some Forths do not bother with it
\   - More modern Forths which optimize more but lose the simplicity
\   of Forth
\   - Lack of user variables, making a ROMable Forth, compression
\ - The document should describe both how, and why, things are the
\ way they are. The design decisions are just as important as the decision
\ itself, more so even, as understand the why a decision was made allows
\ you to change or challenge the implementation.

\ The project, documentation and Forth images are under an MIT license,
\ <https://github.com/howerj/embed/blob/master/LICENSE> and the
\ repository is available at <https://github.com/howerj/embed/>.

\ The document is structured in roughly the following order:
\ 1.  The metacompiler
\ 2.  The assembler
\ 3.  Image header generation
\ 4.  Basic Setup, Variables and Special cases
\ 5.  Simple Forth Words, Numeric I/O
\ 6.  Interpreter
\ 7.  Control Words
\ 8.  I/O Control, Boot Words
\ 9. 'See', the Disassembler
\ 10. Block Editor
\ 11. Finishing
\ 12. APPENDIX

\ What you are reading is itself a Forth program, all the explanatory text is
\ are Forth comments. The file should eventually be fed through a preprocessor 
\ to turn it into a Markdown file for further processing.
\ See <https://daringfireball.net/projects/markdown/> for more information
\ about Markdown.

\ Many Forths are written in an assembly language, especially the ones geared
\ towards microcontrollers, although it is more common for new Forth
\ interpreters to be written in C. A metacompiler is a Cross Compiler
\ <https://en.wikipedia.org/wiki/Cross_compiler> written in Forth.

\ References
\ * 'The Zen of eForth' by C. H. Ting
\ * <https://github.com/howerj/embed> (This project)
\ * <https://github.com/howerj/libforth>
\ * <https://github.com/howerj/forth-cpu>
\ Jones Forth:
\ * <https://rwmj.wordpress.com/2010/08/07/jonesforth-git-repository/>
\ * <https://github.com/AlexandreAbreu/jonesforth>
\ J1 CPU
\ * <excamera.com/files/j1.pdf>
\ * <http://excamera.com/sphinx/fpga-j1.html>
\ * <https://github.com/jamesbowman/j1>
\ * <https://github.com/samawati/j1eforth>

\ The Virtual Machine is specifically designed to execute Forth, it is a stack
\ machine that allows many Forth words to be encoded in one instruction but
\ does not contain any high level Forth words, just words like '@', 'r>' and
\ a few basic words for I/O. A full description of the virtual machine is
\ in the appendix.

\ ## Metacompilation wordset
\ This section defines the metacompilation wordset as well as the
\ assembler. The metacompiler, or cross compiler, requires some assembly
\ instructions to be defined so the two word sets are interlinked. 
\ 
\ A clear understanding of how Forth vocabularies work is needed before
\ proceeding with the tutorial. Vocabularies are the way Forth manages
\ namespaces and are generally talked about that much, they are especially
\ useful (in fact pretty much required) for writing a metacompiler.

only forth definitions hex
variable meta       ( Metacompilation vocabulary )
meta +order definitions

variable assembler.1   ( Target assembler vocabulary )
variable target.1      ( Target dictionary )
variable tcp           ( Target dictionary pointer )
variable tlast         ( Last defined word in target )
variable tdoVar        ( Location of doVar in target )
variable tdoConst      ( Location of doConst in target )
variable tdoNext       ( Location of doNext in target )
variable fence         ( Do not peephole optimize before this point )
1984 constant #version ( Version number )
5000 constant #target  ( Memory location where the target image will be built )
2000 constant #max     ( Max number of cells in generated image )
2    constant =cell    ( Target cell size )
-1   constant optimize ( Turn optimizations on [-1] or off [0] )
0    constant swap-endianess ( if true, swap the endianess )
$4280 constant pad-area    ( area for pad storage )
variable header -1 header ! ( If true Headers in the target will be generated )

1   constant verbose   ( verbosity level, higher is more verbose )
#target #max 0 fill    ( Erase the target memory location )

: ]asm assembler.1 +order ; immediate ( -- )
: a: get-current assembler.1 set-current : ; ( "name" -- wid link )
: a; [compile] ; set-current ; immediate ( wid link -- )

: ( [char] ) parse 2drop ; immediate
: \ source drop @ >in ! ; immediate
: there tcp @ ;         ( -- a : target dictionary pointer value )
: tc! #target + c! ;    ( u a -- )
: tc@ #target + c@ ;    ( a -- u )
: [address] $3fff and ; ( a -- a )
: [last] tlast @ ;      ( -- a )
: low  swap-endianess 0= if 1+ then ; ( b -- b )
: high swap-endianess    if 1+ then ; ( b -- b )
: t! over ff and over high tc! swap 8 rshift swap low tc! ; ( u a -- )
: t@ dup high tc@ swap low tc@ 8 lshift or ; ( a -- u )
: 2/ 1 rshift ;                ( u -- u )
: talign there 1 and tcp +! ;  ( -- )
: tc, there tc! 1 tcp +! ;     ( c -- )
: t,  there t!  =cell tcp +! ; ( u -- )
: tallot tcp +! ;              ( n -- )
: update-fence there fence ! ; ( -- )
: $literal                     ( <string>, -- )
  [char] " word count dup tc, 1- for count tc, next drop talign update-fence ;
: tcells =cell * ;             ( u -- a )
: tbody 1 tcells + ;           ( a -- a )
: s! ! ;                       ( u a -- )
: dump-hex #target there 16 + dump ; ( -- )
: locations ( -- : list all words and locations in target dictionary )
  target.1 @ 
  begin 
    dup 
  while 
    dup 
    nfa count type space dup
    cfa >body @ u. cr
    $3fff and @ 
  repeat drop ;

: display ( -- : display metacompilation and target information )
  verbose 0= if exit then
  hex
  ." COMPILATION COMPLETE" cr
  verbose 1 u> if 
    dump-hex cr 
    ." TARGET DICTIONARY: " cr
    locations
  then
  ." HOST: "       here        . cr
  ." TARGET: "     there       . cr
  ." HEADER: "     #target 20 dump cr ;

: checksum #target there crc ; ( -- u : calculate CRC of target image )

: save-hex ( -- : save target binary to file )
   #target #target there + (save) throw ;

: finished ( -- : save target image and display statistics )
   display
   only forth definitions hex
   ." SAVING... " save-hex ." DONE! " cr
   ." STACK> " .s cr ;

: [a] ( "name" -- : find word and compile an assembler word )
  token assembler.1 search-wordlist 0= if abort" [a]? " then
  cfa compile, ; immediate

: asm[ assembler.1 -order ; immediate ( -- )

\ There are five types of instructions, which are differentiated from each
\ other by the top bits of the instruction. 

a: #literal $8000 a; ( literal instruction - top bit set )
a: #alu     $6000 a; ( ALU instruction, further encoding below... )
a: #call    $4000 a; ( function call instruction )
a: #?branch $2000 a; ( branch if zero instruction )
a: #branch  $0000 a; ( unconditional branch )

\ An ALU instruction has a more complex encoding which can be seen in the table
\ in the appendix, it consists of a few flags for moving values to different
\ registers before and after the ALU operation to perform, an ALU operation,
\ and a return and variable stack increment/decrement.
\ 
\ Some of these operations are more complex than they first appear, either
\ because they do more than a single line explanation allows for, or because
\ they are not typical instructions that you would find in an actual processors
\ ALU and are only possible within the context of a virtual machine. Operations
\ like '#u/mod' are an example of the former, '#save' is an example of the
\ later.
\ 
\ The most succinct description of these operations, and the virtual machine,
\ is the source code for it which weighs in at under two hundred lines of
\ C code. Unfortunately this would not include that rationale that led to
\ the virtual machine being the way it is.

\ ALU Operations
a: #t      0000 a; ( T = t )
a: #n      0100 a; ( T = n )
a: #r      0200 a; ( T = Top of Return Stack )
a: #[t]    0300 a; ( T = memory[t] )
a: #n->[t] 0400 a; ( memory[t] = n )
a: #t+n    0500 a; ( n = n+t, T = carry )
a: #t*n    0600 a; ( n = n*t, T = upper bits of multiplication )
a: #t&n    0700 a; ( T = T and N )
a: #t|n    0800 a; ( T = T  or N )
a: #t^n    0900 a; ( T = T xor N )
a: #~t     0a00 a; ( Invert T )
a: #t-1    0b00 a; ( T == t - 1 )
a: #t==0   0c00 a; ( T == 0? )
a: #t==n   0d00 a; ( T = n == t? )
a: #nu<t   0e00 a; ( T = n < t )
a: #n<t    0f00 a; ( T = n < t, signed version )
a: #n>>t   1000 a; ( T = n right shift by t places )
a: #n<<t   1100 a; ( T = n left  shift by t places )
a: #sp@    1200 a; ( T = variable stack depth )
a: #rp@    1300 a; ( T = return stack depth )
a: #sp!    1400 a; ( set variable stack depth )
a: #rp!    1500 a; ( set return stack depth )
a: #save   1600 a; ( Save memory disk: n = start, T = end, T' = error )
a: #tx     1700 a; ( Transmit Byte: t = byte, T' = error )
a: #rx     1800 a; ( Block until byte received, T = byte/error )
a: #u/mod  1900 a; ( Remainder/Divide: )
a: #/mod   1a00 a; ( Signed Remainder/Divide: )
a: #bye    1b00 a; ( Exit Interpreter )

\ The Stack Delta Operations occur after the ALU operations have been executed.
\ They affect either the Return or the Variable Stack. An ALU instruction
\ without one of these operations (generally) do not affect the stacks.
a: d+1     0001 or a; ( increment variable stack by one )
a: d-1     0003 or a; ( decrement variable stack by one )
a: d-2     0002 or a; ( decrement variable stack by two )
a: r+1     0004 or a; ( increment variable stack by one )
a: r-1     000c or a; ( decrement variable stack by one )
a: r-2     0008 or a; ( decrement variable stack by two )

\ All of these instructions execute after the ALU and stack delta operations
\ have been performed except r->pc, which occurs before. They form part of
\ an ALU operation.
a: r->pc   0010 or a; ( Set Program Counter to Top of Return Stack )
a: n->t    0020 or a; ( Set Top of Variable Stack to Next on Variable Stack )
a: t->r    0040 or a; ( Set Top of Return Stack to Top on Variable Stack )
a: t->n    0080 or a; ( Set Next on Variable Stack to Top on Variable Stack )

\ There are five types of instructions; ALU operations, branches,
\ conditional branches, function calls and literals. ALU instructions
\ comprise of an ALU operation, stack effects and register move bits. Function
\ returns are part of the ALU operation instruction set.

: ?set dup $e000 and if abort" argument too large " then ;
a: branch  2/ ?set [a] #branch  or t, a; ( a -- : an Unconditional branch )
a: ?branch 2/ ?set [a] #?branch or t, a; ( a -- : Conditional branch )
a: call    2/ ?set [a] #call    or t, a; ( a -- : Function call )
a: ALU        ?set [a] #alu     or    a; ( u -- : Make ALU instruction )
a: alu                    [a] ALU  t, a; ( u -- : ALU operation )
a: literal ( n -- : compile a number into target )
  dup [a] #literal and if   ( numbers above $7fff take up two instructions )
    invert recurse  ( the number is inverted, an literal is called again )
    [a] #~t [a] alu ( then an invert instruction is compiled into the target )
  else
    [a] #literal or t, ( numbers below $8000 are single instructions )
  then a;
a: return ( -- : Compile a return into the target )
   [a] #t [a] r->pc [a] r-1 [a] alu a;

\ The following words implement a primitive peephole optimizer, which is not
\ the only optimization done, but is the major one. It performs tail call
\ optimizations and merges the return instruction with the previous instruction
\ if possible. These simple optimizations really make a lot of difference
\ in the size of metacompiled program. It means proper tail recursive 
\ procedures can be constructed.
\ 
\ The optimizer is wrapped up in the "exit," word, it checks a fence variable
\ first, then the previously compiled cell to see if it can replace the last
\ compiled cell.
\ 
\ The fence variable is an address below which the peephole optimizer should
\ not look, this is to prevent the optimizer looking at data and merging with
\ it, or breaking control structures. 
\ 
\ An exit can be merged into an ALU instruction if it does not contain
\ any return stack manipulation, or information from the return stack. This
\ includes operations such as "r->pc", or "r+1". 
\ 
\ A call then an exit can be replaced with an unconditional branch to the
\ call.
\ 
\ If no optimization can be performed an 'exit' instruction is written into
\ the target.
\ 
\ The optimizer can be held off manually be inserting a "nop", or a call
\ or instruction which does nothing, before the 'exit'.
\ 
\ Other optimizations performed by the metacompiler, but not this optimizer,
\ include; inlining constant values and addresses, allowing the creation of
\ headerless words which are named only in the metacompiler and not in the
\ target, and the 'fallthrough;' word which allows for greater code sharing.
\ Some of these optimizations have a manual element to them, such as
\ 'fallthrough;'.

: previous there =cell - ;                      ( -- a )
: lookback previous t@ ;                        ( -- u )
: call? lookback $e000 and [a] #call = ;        ( -- f )
: call>goto previous dup t@ $1fff and swap t! ; ( -- )
: fence? fence @  previous u> ;                 ( -- f )
: safe? lookback $e000 and [a] #alu = lookback $001c and 0= and ; ( -- f )
: alu>return previous dup t@ [a] r->pc [a] r-1 swap t! ; ( -- )
: exit-optimize                                 ( -- )
  fence? if [a] return exit then
  call?  if call>goto  exit then
  safe?  if alu>return exit then
  [a] return ;
: exit, exit-optimize update-fence ;            ( -- )

: compile-only tlast @ t@ $8000 or tlast @ t! ; ( -- )
: immediate tlast @ t@ $4000 or tlast @ t! ;    ( -- )

\ create a word in the metacompilers dictionary, not the targets
: tcreate get-current >r target.1 set-current create r> set-current ;

: thead ( b u -- : compile word header into target dictionary )
  header @ 0= if 2drop exit then
  talign
  there [last] t, tlast ! 
  there #target + pack$ c@ 1+ aligned tcp +! talign ;

: lookahead ( -- b u : parse a word, but leave it in the input stream )
  >in @ >r bl parse r> >in ! ;

\ The word 'h:' creates a headerless word in the target dictionary for
\ space saving reasons and to declutter the target search order. Ideally 
\ it would instead add the word to a different vocabulary, so it is still 
\ accessible to the programmer, but there is already very little room on the
\ target.
: h: ( -- : create a word with no name in the target dictionary )
 $f00d tcreate there , update-fence does> @ [a] call ;

: t: ( "name", -- : creates a word in the target dictionary )
  lookahead thead h: ;

\ @warning: Only use 'fallthrough' to fallthrough to words defined with 'h:'.
: fallthrough; $f00d <> if abort" unstructured! " then ;
: t; fallthrough; optimize if exit, else [a] return then ;

: fetch-xt @ dup 0= if abort" (null) " then ; ( a -- xt )

: tconstant ( "name", n -- , Run Time: -- n )
  >r
  lookahead
  thead
  there tdoConst fetch-xt [a] call r> t, >r
  tcreate r> ,
  does> @ tbody t@ [a] literal ;

: tvariable ( "name", n -- , Run Time: -- a )
  >r
  lookahead
  thead
  there tdoVar fetch-xt [a] call r> t, >r
  tcreate r> ,
  does> @ tbody [a] literal ;

: tlocation ( "name", n -- : Reserve space in target for a memory location )
  there swap t, tcreate , does> @ [a] literal ;

: [t] ( "name", -- a : get the address of a target word )
  token target.1 search-wordlist 0= if abort" [t]? " then
  cfa >body @ ;

\ @warning only use "[u]" on variables, not tlocations 
: [u] [t] =cell + ; ( "name", -- a )

\ xchange takes two vocabularies defined in the target by their variable
\ names, "name1" and "name2", and updates "name1" so it contains the previously
\ defined words, and makes "name2" the vocabulary which subsequent definitions
\ are added to.
: xchange ( "name1", "name2", -- : exchange target vocabularies )
  [last] [t] t! [t] t@ tlast s! ; 

\ These words implement the basic control structures needed to make 
\ applications in the metacompiled program, they are no immediate words
\ and they do not need to be, 't:' and 't;' do not change the interpreter
\ state, once the actual metacompilation begins everything is command mode.
: literal [a] literal ;                      ( u -- )
: begin  there update-fence ;                ( -- a )
: until  [a] ?branch ;                       ( a -- )
: if     there update-fence 0 [a] ?branch  ; ( -- a )
: skip   there update-fence 0 [a] branch ;   ( -- a )
: then   begin 2/ over t@ or swap t! ;       ( a -- )
: else   skip swap then ;                    ( a -- a )
: while  if swap ;                           ( a -- a a )
: repeat [a] branch then update-fence ;      ( a -- )
: again  [a] branch update-fence ;           ( a -- )
: aft    drop skip begin swap ;              ( a -- a )
: constant tcreate , does> @ literal ;       ( "name", a -- )
: [char] char literal ;                      ( "name" )
: tcompile, [a] call ;                       ( a -- )
: tcall [t] tcompile, ;                      ( "name", -- )
: next tdoNext fetch-xt [a] call t, update-fence ; ( a -- )
: exit exit, ;                               ( -- )

\ The following section adds the words implementable in assembly to the
\ metacompiler, when one of these words is used in the metacompiled program
\ it will be implemented in assembly.

: nop     ]asm  #t       alu asm[ ;
: dup     ]asm  #t       t->n   d+1   alu asm[ ;
: over    ]asm  #n       t->n   d+1   alu asm[ ;
: invert  ]asm  #~t      alu asm[ ;
: um+     ]asm  #t+n     alu asm[ ;
: +       ]asm  #t+n     n->t   d-1   alu asm[ ;
: um*     ]asm  #t*n     alu asm[    ;
: *       ]asm  #t*n     n->t   d-1   alu asm[ ;
: swap    ]asm  #n       t->n   alu asm[ ;
: nip     ]asm  #t       d-1    alu asm[ ;
: drop    ]asm  #n       d-1    alu asm[ ;
: >r      ]asm  #n       t->r   d-1   r+1   alu asm[ ;
: r>      ]asm  #r       t->n   d+1   r-1   alu asm[ ;
: r@      ]asm  #r       t->n   d+1   alu asm[ ;
: @       ]asm  #[t]     alu asm[ ;
: !       ]asm  #n->[t]  d-1    alu asm[ ;
: rshift  ]asm  #n>>t    d-1    alu asm[ ;
: lshift  ]asm  #n<<t    d-1    alu asm[ ;
: =       ]asm  #t==n    d-1    alu asm[ ;
: u<      ]asm  #nu<t    d-1    alu asm[ ;
: <       ]asm  #n<t     d-1    alu asm[ ;
: and     ]asm  #t&n     d-1    alu asm[ ;
: xor     ]asm  #t^n     d-1    alu asm[ ;
: or      ]asm  #t|n     d-1    alu asm[ ;
: sp@     ]asm  #sp@     t->n   d+1   alu asm[ ;
: sp!     ]asm  #sp!     alu asm[ ;
: 1-      ]asm  #t-1     alu asm[ ;
: rp@     ]asm  #rp@     t->n   d+1   alu asm[ ;
: rp!     ]asm  #rp!     d-1    alu asm[ ;
: 0=      ]asm  #t==0    alu asm[ ;
: (bye)   ]asm  #bye     alu asm[ ;
: rx?     ]asm  #rx      t->n   d+1   alu asm[ ;
: tx!     ]asm  #tx      n->t   d-1   alu asm[ ;
: (save)  ]asm  #save    d-1    alu asm[ ;
: u/mod   ]asm  #u/mod   t->n   alu asm[ ;
: /mod    ]asm  #u/mod   t->n   alu asm[ ;
: /       ]asm  #u/mod   d-1    alu asm[ ;
: mod     ]asm  #u/mod   n->t   d-1   alu asm[ ;
: rdrop   ]asm  #t       r-1    alu asm[ ;
\ Some words can be implemented in a single instruction which have no
\ analogue within Forth.
: dup-@   ]asm  #[t]     t->n   d+1 alu asm[ ;
: dup>r   ]asm  #t       t->r   r+1 alu asm[ ;
: 2dup=   ]asm  #t==n    t->n   d+1 alu asm[ ;
: 2dup-xor ]asm #t^n     t->n   d+1 alu asm[ ;
: rxchg   ]asm  #r       t->r       alu asm[ ;

\ 'for' needs the new definition of '>r' to work correctly.
: for >r begin ;
: s: : ;

: :noname h: ;
: : t: ;
s: ; t; ;
hide s:

]asm #~t              ALU asm[ constant =invert ( invert instruction )
]asm #t  r->pc    r-1 ALU asm[ constant =exit   ( return/exit instruction )
]asm #n  t->r d-1 r+1 ALU asm[ constant =>r     ( to r. stk. instruction )
$20   constant =bl         ( blank, or space )
$d    constant =cr         ( carriage return )
$a    constant =lf         ( line feed )
$8    constant =bs         ( back space )
$1b   constant =escape     ( escape character )

$10   constant dump-width  ( number of columns for 'dump' )
$50   constant tib-length  ( size of terminal input buffer )
$1f   constant word-length ( maximum length of a word )

$40   constant c/l         ( characters per line in a block )
$10   constant l/b         ( lines in a block )
$4400 constant sp0         ( start of variable stack )
$7fff constant rp0         ( start of return stack )

( Volatile variables )
$4000 constant _test       ( used in skip/test )
$4002 constant last-def    ( last, possibly unlinked, word definition )
$4006 constant id          ( used for source id )
$4008 constant seed        ( seed used for the PRNG )
$400A constant handler     ( current handler for throw/catch )
$400C constant block-dirty ( -1 if loaded block buffer is modified )
$4010 constant _key        ( -- c : new character, blocking input )
$4012 constant _emit       ( c -- : emit character )
$4014 constant _expect     ( "accept" vector )
\ $4016 constant _tap      ( "tap" vector, for terminal handling )
\ $4018 constant _echo     ( c -- : emit character )
$4020 constant _prompt     ( -- : display prompt )
$4110 constant context     ( holds current context for search order )
$4122 constant #tib        ( Current count of terminal input buffer )
$4124 constant tib-buf     ( ... and address )
$4126 constant tib-start   ( backup tib-buf value )
\ $4280 == pad-area    

$c    constant header-length ( location of length in header )
$e    constant header-crc    ( location of CRC in header )

\ # Target Words
\ With the assembler and meta compiler complete, we can now make our target
\ application, a Forth interpreter which will be able to read in this file
\ and create new, possibly modified, images for the Forth virtual machine
\ to run.

target.1 +order         ( Add target word dictionary to search order )
meta -order meta +order ( Reorder so 'meta' has a higher priority )
forth-wordlist   -order ( Remove normal Forth words to prevent accidents )

\ The following 't,' sequence reserves space and partially populates the
\ image header with file format information, based upon the PNG specification.
\ See <http://www.fadden.com/tech/file-formats.html> and
\ <https://stackoverflow.com/questions/323604> for more information about
\ how to design binary formats.
\ 
\ The header contains enough information to identify the format, the
\ version of the format, and to detect corruption of data, as well as
\ having a few other nice properties - some having to do with how other
\ systems and programs may deal with the binary (such as have a string literal
\ 'FTH' to help identify the binary format, and the first byte being outside
\ the ASCII range of characters so it is obvious that the file is meant to
\ be treated as a binary and not as text).
\ 

0        t, \  $0: First instruction executed, jump to start / reset vector
0        t, \  $2: Instruction exception vector
$4689    t, \  $4: 0x89 'F'
$4854    t, \  $6: 'T'  'H'
$0a0d    t, \  $8: '\r' '\n'
$0a1a    t, \  $A: ^Z   '\n'
0        t, \  $C: For Length
0        t, \  $E: For CRC
$0001    t, \ $10: Endianess check
#version t, \ $12: Version information

\ After the header two short words are defined, visible only to the meta
\ compiler and used by its internal machinery. The words are needed by
\ 'tvariable' and 'tconstant', and these constructs cannot be used without
\ them. This is an example of the metacompiler and the metacompiled program
\ being intermingled, which should be kept to a minimum.

h: doVar   r> ;    ( -- a : push return address and exit to caller )
h: doConst r> @ ;  ( -- u : push value at return address and exit to caller )

\ Here the address of 'doVar' and 'doConst' in the target is stored in 
\ variables accessible by the metacompiler, so 'tconstant' and 'tvariable' can
\ compile references to them in the target.
\ 

[t] doVar tdoVar s!
[t] doConst tdoConst s!

\ Next some space is reserved for variables which will have no name in the
\ target and are not on the target Forths search order. We do this with
\ 'tlocation'. These variables are needed for the internal working of the
\ interpreter but the application programmer using the target Forth can make
\ do without them.
\ 
\ @todo explain the vocabularies variables, and other variables here.

0 tlocation cp                ( Dictionary Pointer: Set at end of file )
0 tlocation root-voc          ( root vocabulary )
0 tlocation editor-voc        ( editor vocabulary )
0 tlocation assembler-voc     ( assembler vocabulary )
0 tlocation _forth-wordlist   ( set at the end near the end of the file )
0 tlocation current           ( WID to add definitions to )

\ ## Target Assembly Words

\ The first words added to the target Forths dictionary are all based on 
\ assembly instructions. The definitions may seem like nonsense, how does the
\ definition of '+' work? It appears that the definition calls itself, which
\ obviously would not work. The answer is in the order new words are added
\ into the dictionary. In Forth, a word definition is not placed in the
\ search order until the definition of that word is complete, this allows
\ the previous definition of a word to be use within that definition, and
\ requires a separate word ("recurse") to implement recursion. 
\ 
\ @todo rewrite the following section as 't:' and 't;' are now ':' and ';'
\ However, the words 't:' and 't;' are not the same as the words ':' and
\ ';'. 't:' uses 'create' to make a new variable in the metacompilers 
\ dictionary that points to a word definition in the target, it also creates
\ the words header in the target ('h:' is the same, but without a header
\ being made in the target). The word is compilable into the target as soon
\ as it is defined, yet the definition of '+' is not recursive because the
\ metacompilers search order, "meta", is higher that the search order for
\ the words containing the metacompiled target addresses, "target.1", so the
\ assembly for '+' gets compiled into the definition of '+'.
\ 
\ Manipulation of the word search order is key in understanding how the
\ metacompiler works.
\ 

: nop      nop      ; ( -- : do nothing )
: dup      dup      ; ( n -- n n : duplicate value on top of stack )
: over     over     ; ( n1 n2 -- n1 n2 n1 : duplicate second value on stack )
: invert   invert   ; ( u -- u : bitwise invert of value on top of stack )
: um+      um+      ; ( u u -- u carry : addition with carry )
: +        +        ; ( u u -- u : addition without carry )
: um*      um*      ; ( u u -- ud : multiplication  )
: *        *        ; ( u u -- u : multiplication )
: swap     swap     ; ( n1 n2 -- n2 n1 : swap two values on stack )
: nip      nip      ; ( n1 n2 -- n2 : remove second item on stack )
: drop     drop     ; ( n -- : remove item on stack )
: @        @        ; ( a -- u : load value at address )
: !        !        ; ( u a -- : store 'u' at address 'a' )
: rshift   rshift   ; ( u1 u2 -- u : shift u2 by u1 places to the right )
: lshift   lshift   ; ( u1 u2 -- u : shift u2 by u1 places to the left )
: =        =        ; ( u1 u2 -- f : does u2 equal u1? )
: u<       u<       ; ( u1 u2 -- f : is u2 less than u1 )
: <        <        ; ( u1 u2 -- f : is u2 less than u1, signed version )
: and      and      ; ( u u -- u : bitwise and )
: xor      xor      ; ( u u -- u : bitwise exclusive or )
: or       or       ; ( u u -- u : bitwise or )
: sp@      sp@      ; ( ??? -- u : get stack depth )
: sp!      sp!      ; ( u -- ??? : set stack depth )
: 1-       1-       ; ( u -- u : decrement top of stack )
: 0=       0=       ; ( u -- f : if top of stack equal to zero )
: (bye)    (bye)    ; ( u -- !!! : exit VM with 'u' as return value )
: rx?      rx?      ; ( -- c | -1 : fetch a single character, or EOF )
: tx!      tx!      ; ( c -- : transmit single character )
: (save)   (save)   ; ( u1 u2 -- u : save memory from u1 to u2 inclusive )
: u/mod    u/mod    ; ( u1 u2 -- rem div : unsigned divide/modulo )
: /mod     /mod     ; ( u1 u2 -- rem div : signed divide/modulo )
: /        /        ; ( u1 u2 -- u : u1 divided by u2 )
: mod      mod      ; ( u1 u2 -- u : remainder of u1 divided by u2 )

\ These words can also be implemented in a single instruction, yet their
\ definition is different for multiple reasons. These words should only be
\ use within a word definition begin defined with the running target Forth,
\ so they have a bit set in their header indicating as such.
\ 
\ Another difference is how these words are compiled into a word definition
\ in the target, which is due to the fact they manipulate the return stack.
\ These words are 'inlined', which means the instruction they contain is
\ written directly into a definition being defined in the running target
\ Forth instead of a call to a word that contains the assembly instruction,
\ calls obviously change the return stack, so these words would either have
\ to take that into account or the assembly instruction could be inlined,
\ the later option has been taken.
\ 
\ As these words are never actually called, as they are only of use in
\ compile mode, and then they are inlined instead of being called, we can
\ leave off ';' which would write an exit instruction on the end of the
\ definition.
\ 

there constant inline-start 
: rp@   rp@   fallthrough; compile-only ( -- u )
: rp!   rp!   fallthrough; compile-only ( u --, R: --- ??? )
: exit  exit  fallthrough; compile-only ( -- )
: >r    >r    fallthrough; compile-only ( u --, R: -- u )
: r>    r>    fallthrough; compile-only ( -- u, R: u -- )
: r@    r@    fallthrough; compile-only ( -- u )
: rdrop rdrop fallthrough; compile-only ( --, R: u -- )
there constant inline-end 

[last] [t] assembler-voc t!

$2       tconstant cell  ( size of a cell in bytes )
$0       tvariable >in   ( Hold character pointer when parsing input )
$0       tvariable state ( compiler state variable )
$0       tvariable hld   ( Pointer into hold area for numeric output )
$10      tvariable base  ( Current output radix )
$0       tvariable span  ( Hold character count received by expect   )
$8       tconstant #vocs ( number of vocabularies in allowed )
$400     tconstant b/buf ( size of a block )
0        tvariable blk   ( current blk loaded, set in 'cold' )
#version tconstant ver   ( eForth version )
0        tvariable boot  ( -- : execute program at startup )
pad-area tconstant pad   ( pad variable - offset into temporary storage )

\ The following section of words is purely a space saving measure, or
\ they allow for other optimizations which also save space. Examples
\ of this include "[-1]"; any number about $7fff requires two instructions
\ to encode, numbers below only one, -1 is a commonly used number so this
\ allows us to save on space. 
\ 
\ This does not explain the creation of a word to push the number zero 
\ though, this only takes up one instruction.  This is instead explained 
\ by the interaction of the peephole optimizer with function calls, calls
\ to function can be turned into a branch if that instruction were to be
\ followed by an exit instruction because it is at the end of a word
\ definition. This cannot be said of literals. This allows us to save
\ space under special circumstances.
\ 
\ The following example illustrates this:
\ 
\  | FORTH CODE                   | PSEUDO ASSEMBLER         |
\  | ---------------------------- | ------------------------ |
\  | : push-zero 0 literal ;      | LITERAL(0) EXIT          |
\  | : example-1 drop 0 literal ; | DROP LITERAL(0) EXIT     |
\  | : example-2 drop 0 literal ; | DROP BRANCH(push-zero)   |
\ 
\ Where "example-1" being unoptimized requires three instructions, whereas
\ "example-2" requires only two, with the two instruction overhead of
\ "push-zero".
\ 
\ Optimizations like this explain some of the structure of the Forth
\ code, it is better to exit early and heavily factorize code if space is at 
\ a premium, which it is due to the way the virtual machine works (both it
\ being 16-bit only, and only allowing the first 16KiB to be used for program
\ storage). Factoring code like this is similar to performing LZW compression,
\ or similar dictionary related compression schemes.
\ <https://www.cs.duke.edu/csed/curious/compression/lzw.html>
\ <https://en.wikipedia.org/wiki/Lempel%E2%80%93Ziv%E2%80%93Welch>
\ 
\ Whilst factoring words into smaller, cleaner, definitions is highly
\ encouraged for Forth code (it is often an art coming up with the right
\ word name and associated concept it encapsulates), making words like
\ "2drop-0" is not. It hurts readability as there is no reason or idea backing
\ a word like "2drop-0", even if it is fairly clear what it does from its
\ name.
\ 
h: [-1] -1 literal ;         ( -- -1 : space saving measure, push -1 )
h: 0x8000 $8000 literal ;    ( -- $8000 : space saving measure, push $8000 )
h: 2drop-0 drop fallthrough;  ( n n -- 0 )
h: drop-0 drop fallthrough;   ( n -- 0 )
h: 0x0000 $0000 literal ;    ( -- $0000 : space/optimization, push $0000 )
h: state@ state @ ;          ( -- u )
h: first-bit 1 literal and ; ( u -- u )
h: in! >in ! ;               ( u -- )
h: in@ >in @ ;               ( -- u )

\ Now the implementation of the Forth interpreter without the apologies
\ for the words in the prior section. This group of words implement some
\ of the basic words expected in Forth; simple stack manipulation, tests,
\ and other one, or two line definitions that do not really require an
\ explanation of how they work - only why they are useful. Some of the words 
\ are described by their stack comment entirely, like "2drop", other like
\ "cell+" require a reason for such a simple word (they embody a concept or
\ they help hide implementation details).

: 2drop drop drop ;        ( n n -- )
: 1+ 1 literal + ;         ( n -- n : increment a value  )
: negate invert 1+ ;       ( n -- n : negate a number )
: - negate + ;             ( n1 n2 -- n : subtract n1 from n2 )
h: over- over - ;           ( u u -- u u )
h: over+ over + ;           ( u1 u2 -- u1 u1+2 )
: aligned dup first-bit + ; ( b -- a )
: bye 0 literal (bye) ;    ( -- : leave the interpreter )
: cell- cell - ;           ( a -- a : adjust address to previous cell )
: cell+ cell + ;           ( a -- a : move address forward to next cell )
: cells 1 literal lshift ; ( n -- n : convert cells count to address count )
: chars 1 literal rshift ; ( n -- n : convert bytes to number of cells )
: ?dup dup if dup exit then ; ( n -- 0 | n n : duplicate non zero value )
: >  swap < ;              ( n1 n2 -- f : signed greater than, n1 > n2 )
: u> swap u< ;             ( u1 u2 -- f : unsigned greater than, u1 > u2 )
: u>= u< invert ;          ( u1 u2 -- f : unsigned greater/equal )
: <> = invert ;            ( n n -- f : not equal )
: 0<> 0= invert ;          ( n n -- f : not equal  to zero )
: 0> 0 literal > ;         ( n -- f : greater than zero? )
: 0< 0 literal < ;         ( n -- f : less than zero? )
: 2dup over over ;         ( n1 n2 -- n1 n2 n1 n2 )
: tuck swap over ;         ( n1 n2 -- n2 n1 n2 )
: +! tuck @ +  fallthrough; ( n a -- : increment value at 'a' by 'n' )
h: swap! swap ! ;           ( a u -- )
: 1+!  1 literal swap +! ; ( a -- : increment value at address by 1 )
: 1-! [-1] swap +! ;       ( a -- : decrement value at address by 1 )
: execute >r ;             ( cfa -- : execute a function )
: c@ dup-@ swap first-bit   ( b -- c )
   if
      8 literal rshift exit
   then
   $ff literal and ;                   
: c!  ( c b -- )               
  swap $ff literal and dup 8 literal lshift or swap
  swap over dup @ swap first-bit 0= $ff literal xor
  >r over xor r> and xor swap ! ;      ( c b -- )
h: string@ over c@ ;                   ( b u -- b u c )
: 2! ( d a -- ) tuck ! cell+ ! ;      ( n n a -- )
: 2@ ( a -- d ) dup cell+ @ swap @ ;  ( a -- n n )
: command? state@ 0= ;                ( -- f )
: get-current current @ ;             ( -- wid )
: set-current current ! ;             ( wid -- )
: here cp @ ;                         ( -- a )
: align here fallthrough;              ( -- )
h: cp! aligned cp ! ;                  ( n -- )
: source #tib 2@ ;                    ( -- a u )
: source-id id @ ;                    ( -- 0 | -1 )
h: @execute @ ?dup if >r then ;        ( cfa -- )
: bl =bl ;                            ( -- c )
: within over- >r - r> u< ;           ( u lo hi -- f )
\ t: dnegate invert >r invert 1 literal um+ r> + ; ( d -- d )
: abs dup 0< if negate exit then ;    ( n -- u )
: count dup 1+ swap c@ ;              ( cs -- b u )
: rot >r swap r> swap ;               ( n1 n2 n3 -- n2 n3 n1 )
: -rot swap >r swap r> ;              ( n1 n2 n3 -- n3 n1 n2 )
\ @warning be careful with '2>r' and '2r>' as peephole optimizer can
\ break these words. They should not be used before an 'exit' or a ';'.
h: 2>r rxchg swap >r >r ;              ( u1 u2 --, R: -- u1 u2 )
h: 2r> r> r> swap rxchg nop ;          ( -- u1 u2, R: u1 u2 -- )
h: doNext 2r> ?dup if 1- >r @ >r exit then cell+ >r ;
[t] doNext tdoNext s!
: min 2dup < fallthrough;              ( n n -- n )
h: mux if drop exit then nip ;         ( n1 n2 b -- n : multiplex operation )
: max 2dup > mux ;                    ( n n -- n )

h: >char $7f literal and dup $7f literal =bl within
  if drop [char] _ then ;              ( c -- c )
h: tib #tib cell+ @ ;                  ( -- a )
\ h: echo _echo @execute ;             ( c -- )
: key _key @execute dup [-1] ( <-- EOF = -1 ) = if bye then ; ( -- c )
: allot cp +! ;                       ( n -- )
: /string over min rot over+ -rot - ; ( b u1 u2 -- b u : advance string u2 )
h: +string 1 literal /string ;         ( b u -- b u : )
h: @address @ fallthrough;              ( a -- a )
h: address $3fff literal and ;         ( a -- a : mask off address bits )
h: last get-current @address ;         ( -- pwd )
: emit _emit @execute ;               ( c -- : write out a char )
: cr =cr emit =lf emit ;              ( -- : emit a newline )
: space =bl emit ;                    ( -- : emit a space )

h: depth sp@ sp0 - chars ;             ( -- u : get current depth )
h: vrelative cells sp@ swap - ;        ( u -- u )
: pick  vrelative @ ;                 ( vn...v0 u -- vn...v0 vu )

: type 0 literal fallthrough;          ( b u -- )
h: typist                               ( b u f -- : print a string )
  >r begin dup while
    swap count r@
    if
      >char
    then
    emit
    swap 1-
  repeat
  rdrop 2drop ;
h: print count type ;                    ( b -- )
h: $type [-1] typist ;                   ( b u --  )
h: decimal? [char] 0 [char] : within ;   ( c -- f : decimal char? )
h: lowercase? [char] a [char] { within ; ( c -- f )
h: uppercase? [char] A [char] [ within ; ( c -- f )
h: >lower                                 ( c -- c : convert to lower case )
  dup uppercase? if =bl xor exit then ;
: spaces =bl fallthrough;                ( +n -- )
h: nchars                                 ( +n c -- : emit c n times )
  swap 0 literal max for aft dup emit then next drop ;
: cmove for aft >r dup c@ r@ c! 1+ r> 1+ then next 2drop ; ( b b u -- )
: fill swap for swap aft 2dup c! 1+ then next 2drop ; ( b u c -- )
h: ndrop for aft drop then next ; ( 0u....nu n -- : drop n cells )

\ t: even first-bit 0= ;
\ t: odd even 0= ;

: catch
  sp@ >r
  handler @ >r
  rp@ handler !
  execute
  r> handler !
  r> drop-0 ;

: throw
  ?dup if
    handler @ rp!
    r> handler !
    rxchg ( <-- r> swap >r )
    sp! drop r>
  then ;

h: -throw negate throw ;  ( u -- : negate and throw )
[t] -throw 2/ 2 t! 

h: 1depth 1 literal fallthrough; ( ??? -- : check depth is at least one  )
h: ?ndepth depth 1- u> if 4 literal -throw exit then ;

\ The words 'um+', 'um/mod' and 'm/mod' are provided as source code, although
\ they are not needed as the virtual machine allows them to be implemented
\ as single instructions.
\ 
\ 	: um+ ( w w -- w carry )
\ 	  over over + >r
\ 	  r@ 0 literal < invert >r
\ 	  over over and
\ 	  0 literal < r> or >r
\ 	  or 0 literal < r> and invert 1 literal +
\ 	  r> swap ; 
\ 
\ 	constant #bits $f
\ 	constant #high $e ( number of bits - 1, highest bit )
\ 	: um/mod ( ud u -- ur uq )
\ 	  ?dup 0= if $a literal -throw exit then
\ 	  2dup u<
\ 	  if negate #high
\ 	    for >r dup um+ >r >r dup um+ r> + dup
\ 	      r> r@ swap >r um+ r> or
\ 	      if >r drop 1+ r> else drop then r>
\ 	    next
\ 	    drop swap exit
\ 	  then drop 2drop [-1] dup ;
\ 
\ 	: m/mod ( d n -- r q ) \ floored division
\ 	  dup 0< dup>r
\ 	  if
\ 	    negate >r dnegate r>
\ 	  then
\ 	  >r dup 0< if r@ + then r> um/mod r>
\ 	  if swap negate swap exit then ;

: decimal $a literal base ! ;              ( -- )
: hex     $10 literal base ! ;             ( -- )
h: radix base @ dup 2 literal - $22 literal u> ( -- u )
  if hex $28 literal -throw exit then ;
h: digit  9 literal over < 7 literal and + [char] 0 + ; ( u -- c )
h: extract u/mod swap ;                     ( n base -- n c )
: hold  hld @ 1- dup hld ! c! fallthrough;  ( c -- )
h: ?hold hld @ pad $100 literal + u> if $11 literal -throw exit then ;  ( -- )
\ t: holds begin dup while 1- 2dup + c@ hold repeat 2drop ;
: sign  0< if [char] - hold exit then ;    ( n -- )
: #>  drop hld @ pad over- ;               ( w -- b u )
: #  1depth radix extract digit hold ;     ( u -- u )
: #s begin # dup while repeat ;            ( u -- 0 )
: <#  pad hld ! ;                          ( -- )
h: str ( n -- b u : convert a signed integer to a numeric string )
  dup>r abs <# #s r> sign #> ;
h: adjust over- spaces type ;     ( b n n -- )
:  .r >r str r> adjust ;         ( n n -- : print n, right justified by +n )
h: (u.) <# #s #> ;                ( u -- : )
: u.r >r (u.) r> adjust ;        ( u +n -- : print u right justified by +n)
: u.  (u.) space type ;          ( u -- : print unsigned number )
:  . ( n -- print space, signed number )
   radix $a literal xor if u. exit then str space type ;
: ? @ . ; ( a -- : display the contents in a memory cell )
\ : .base base @ dup decimal base ! ; ( -- )

: pack$ ( b u a -- a ) \ null fill
  aligned dup>r over
  dup cell negate and ( align down )
  - over+ 0 literal swap! 2dup c! 1+ swap cmove r> ;

\ : ^h ( bot eot cur c -- bot eot cur )
\   >r over r@ < dup
\   if
\     =bs dup echo =bl echo echo
\   then r> + ;

\ : ktap ( bot eot cur c -- bot eot cur )
\   dup =lf ( <-- was =cr ) xor
\   if =bs xor
\     if =bl tap else ^h then
\     exit
\   then drop nip dup ;

h: tap ( dup echo ) over c! 1+ ; ( bot eot cur c -- bot eot cur )
: accept ( b u -- b u )
  over+ over
  begin
    2dup-xor
  while
    key dup =lf xor if tap else drop nip dup then
    ( key  dup =bl - 95 u< if tap else _tap @execute then )
  repeat drop over- ;

: expect _expect @execute span ! drop ; ( b u -- )
: query tib tib-length _expect @execute #tib ! drop-0 in! ; ( -- )

: =string ( a1 u2 a1 u2 -- f : string equality )
  >r swap r> ( a1 a2 u1 u2 )
  over xor if drop 2drop-0 exit then
  for ( a1 a2 )
    aft
      count >r swap count r> xor
      if rdrop 2drop-0 exit then
    then
  next 2drop [-1] ;

: nfa address cell+ ; ( pwd -- nfa : move to name field address)
: cfa nfa dup c@ + cell+ $fffe literal and ; ( pwd -- cfa )
h: .id nfa print ;                            ( pwd -- : print out a word )
h: immediate? @ $4000 literal and fallthrough; ( pwd -- f : immediate word? )
h: logical 0= 0= ;                            ( n -- f )
h: compile-only? @ 0x8000 and logical ;       ( pwd -- f : is compile only? )
h: inline? inline-start inline-end within ;   ( pwd -- f : is word inline? )

h: searcher ( a a -- pwd pwd 1 | pwd pwd -1 | 0 : find a word in a vocabulary )
  swap >r dup
  begin
    dup
  while
    dup nfa count r@ count =string
    if ( found! )
      dup immediate? if 1 literal else [-1] then
      rdrop exit
    then
    nip dup @address
  repeat
  rdrop 2drop-0 ;

h: finder ( a -- pwd pwd 1 | pwd pwd -1 | 0 a 0 : find a word dictionary )
  >r
  context
  begin
    dup-@
  while
    dup-@ @ r@ swap searcher ?dup
    if
      >r rot drop r> rdrop exit
    then
    cell+
  repeat drop-0 r> 0x0000 ;

: search-wordlist searcher rot drop ; ( a wid -- pwd 1 | pwd -1 | a 0 )
: find ( a -- pwd 1 | pwd -1 | a 0 : find a word in the dictionary )
  finder rot drop ;

h: numeric? ( char -- n|-1 : convert character in 0-9 a-z range to number )
  >lower
  dup lowercase? if $57 literal - exit then ( 97 = 'a', +10 as 'a' == 10 )
  dup decimal?   if [char] 0 - exit then 
  drop [-1] ;

h: digit? >lower numeric? base @ u< ; ( c -- f : is char a digit given base )
h: do-number ( n b u -- n b u : convert string )
  begin
    ( get next character )
    2dup 2>r drop c@ dup digit? ( n char bool, Rt: b u )
    if   ( n char )
      swap base @ * swap numeric? + ( accumulate number )
    else ( n char )
      drop
      2r> ( restore string )
      nop exit
    then
    2r> ( restore string )
    +string dup 0= ( advance string and test for end )
  until ;

h: negative? ( b u -- f : is >number negative? )
  string@ $2D literal = if +string [-1] exit then 0x0000 ; 

h: base? ( b u -- )
  string@ $24 literal = ( $hex )
  if
    +string hex exit
  then ( #decimal )
  string@ [char] # = if +string decimal exit then ;

h: >number ( n b u -- n b u : convert string )
  radix >r
  negative? >r
  base?
  do-number
  r> if rot negate -rot then
  r> base ! ;

: number? 0 literal -rot >number nip 0= ; ( b u -- n f : is number? )

h: -trailing ( b u -- b u : remove trailing spaces )
  for
    aft =bl over r@ + c@ <
      if r> 1+ exit then
    then
  next 0x0000 ;

\ @todo rewrite so 'lookfor' does not use vectored word execution

h: lookfor ( b u c -- b u : skip until _test succeeds )
  >r
  begin
    dup
  while
    string@ r@ - r@ =bl = _test @execute if rdrop exit then
    +string
  repeat rdrop ;

h: skipTest if 0> exit then 0<> ; ( n f -- f )
h: scanTest skipTest invert ; ( n f -- f )
h: skipper [t] skipTest literal _test ! lookfor ; ( b u c -- u c )
h: scanner [t] scanTest literal _test ! lookfor ; ( b u c -- u c )

h: parser ( b u c -- b u delta )
  >r over r> swap 2>r 
  r@ skipper 2dup
  r> scanner swap r> - >r - r> 1+ ;

: parse ( c -- b u ; <string> )
   >r tib in@ + #tib @ in@ - r> parser >in +! -trailing 0 literal max ;
: ) ; immediate ( -- : do nothing )
: ( $29 literal parse 2drop ; immediate \ ) ( parse until matching paren )
: .( $29 literal parse type ; ( print out text until matching parenthesis )
: \ #tib @ in! ; immediate ( comment until new line )
h: ?length dup word-length u> if $13 literal -throw exit then ;
: word 1depth parse ?length here pack$ ; ( c -- a ; <string> )
: token =bl word ;                       ( -- a )
: char token count drop c@ ;             ( -- c; <string> )
h: unused $4000 literal here - ;          ( -- u : unused program space )
h: .free unused u. ;                      ( -- : print unused program space )

h: preset ( tib ) tib-start #tib cell+ ! 0 literal in! 0 literal id ! ;
: ] [-1]       state ! ;
: [  0 literal state ! ; immediate

h: ?error ( n -- : perform actions on error )
  ?dup if
    .             ( print error number )
    [char] ? emit ( print '?' )
    cr
    sp0 sp!       ( empty stack )
    preset        ( reset I/O streams )
    [             ( back into interpret mode )
    exit
  then ;

h: ?dictionary dup $3f00 literal u> if 8 literal -throw exit then ;
: , here dup cell+ ?dictionary cp! ! ; ( u -- : store 'u' in dictionary )
: c, here ?dictionary c! cp 1+! ; ( c -- : store 'c' in the dictionary )
h: doLit 0x8000 or , ;
\ @todo make 'literal' a word that relies on vectorized execution
\ This will make the cross compiler simpler, we can just use a number
\ inside a metacompiled word instead of the number followed by 'literal'.
: literal ( n -- : write a literal into the dictionary )
  dup 0x8000 and ( n > $7fff ? )
  if
    invert doLit =invert , exit ( store inversion of n the invert it )
  then
  doLit ( turn into literal, write into dictionary )
  ; compile-only immediate

h: make-callable chars $4000 literal or ; ( cfa -- instruction )
: compile, make-callable , ; ( cfa -- : compile a code field address )
h: $compile dup inline? if cfa @ , exit then cfa compile, ; ( pwd -- )
h: not-found source type $d literal -throw ; ( -- : throw 'word not found' )

\ @todo more words should have vectored execution
\ such as: interpret, literal, abort, page, at-xy, ?error. We can then
\ use the new vectored literal so inbetween 'h:' or 't:' and ';' numbers
\ are instead written into the target, to make things easier. (Perhaps
\ 't:' and ';' could also be replaced by ':' and ';'.

h: ?compile dup compile-only? if source type $e literal -throw exit then ;
h: interpret ( ??? a -- ??? : The command/compiler loop )
  find ?dup if
    state@
    if
      0> if cfa execute exit then ( <- immediate word )
      $compile exit               ( <- compiling word )
    then
    drop ?compile cfa execute exit
  then 
  \ not a word
  dup count number? if
    nip
    state@ if [t] literal tcompile, exit then exit
  then
  ( drop space print ) not-found ;

: immediate last $4000 literal fallthrough; ( -- : previous word immediate )
h: toggle over @ xor swap! ;           ( a u -- : xor value at addr with u )
h: do$ r> r@ r> count + aligned >r swap >r ; ( -- a )
h: $"| do$ nop ; ( -- a : do string NB. nop to fool optimizer )
h: ."| do$ print ; ( -- : print string  )

h: .ok command? if ."| $literal  ok  " cr exit then ; ( -- )
h: ok _prompt @execute ;                              ( -- : execute prompt )
h: ?depth sp@ sp0 u< if 4 literal -throw exit then ;  ( u -- : depth check )
h: eval begin token dup c@ while interpret ?depth repeat drop ok ; ( -- )
: quit preset [ begin query [t] eval literal catch ?error again ; ( -- )
: ok! _prompt ! ; ( xt -- : set ok prompt execution token )

h: get-input source in@ id @ _prompt @ ; ( -- n1...n5 )
h: set-input ok! id ! in! #tib 2! ;      ( n1...n5 -- )
: evaluate ( a u -- )
  get-input 2>r 2>r >r
  0 literal [-1] 0 literal set-input
  [t] eval literal catch
  r> 2r> 2r> set-input
  throw ;

h: ccitt ( crc c -- crc : crc polynomial $1021 AKA "x16 + x12 + x5 + 1" )
  over $8 literal rshift xor    ( crc x )
  dup  $4 literal rshift xor    ( crc x )
  dup  $5 literal lshift xor    ( crc x )
  dup  $c literal lshift xor    ( crc x )
  swap $8 literal lshift xor ; ( crc )

: crc ( b u -- u : calculate ccitt-ffff CRC )
  $ffff literal >r
  begin
    dup
  while
   string@ r> swap ccitt >r 1 literal /string
  repeat 2drop r> ;

: random ( -- u : pseudo random number )
  seed @ 0= seed swap toggle seed @ 0 literal ccitt dup seed ! ; 

\ h: not-implemented 15 literal -throw ;
\ [t] not-implemented tvariable =page
\ [t] not-implemented tvariable =at-xy
\ t: page =page @execute ;   ( -- : page screen )
\ t: at-xy =at-xy @execute ; ( x y -- : set cursor position )

h: 5u.r 4 literal u.r ;     ( u -- )
h: colon $3a literal emit ; ( -- )

\ t: d. base @ >r decimal  . r> base ! ;
\ t: h. base @ >r hex     u. r> base ! ;

\ ## I/O Control 
\ The I/O control section is a relic from eForth that is not really needed
\ in a hosted Forth, at least one where the terminal emulator used handles
\ things like line editing. It is left in here so it can be quickly be added
\ back in if this Forth were to be ported to an embed environment, one in
\ which communications with the Forth took place over a UART.

\ Open and reading from different files is also not needed, it is handled
\ by the virtual machine.

h: io! preset fallthrough;  ( -- : initialize I/O )
h: console [t] rx? literal _key ! [t] tx! literal _emit ! fallthrough;
h: hand [t] .ok  literal ( ' "drop" <-- was emit )  ( ' ktap ) fallthrough;
h: xio  [t] accept literal _expect ! ( _tap ! ) ( _echo ! ) ok! ;
\ h: pace 11 emit ;
\ t: file [t] pace literal [t] drop literal [t] ktap literal xio ;

\ ## Control Structures

h: ?check ( $cafe -- : check for magic number on the stack )
   $cafe literal <> if $16 literal -throw exit then ;
h: ?unique ( a -- a : print a message if a word definition is not unique )
  dup last @ searcher
  if
    ( source type )
    space
    2drop last-def @ nfa print  ."| $literal  redefined " cr exit
  then ;
h: ?nul ( b -- : check for zero length strings )
   count 0= if $a literal -throw exit then 1- ;
h: find-cfa token find if cfa exit then not-found ; ( -- xt, <string> )
: ' find-cfa state@ if tcall literal exit then ; immediate
: [compile] find-cfa compile, ; immediate compile-only  ( --, <string> )
\ NB. 'compile' only works for words, instructions, and numbers below $8000
: compile  r> dup-@ , cell+ >r ; ( -- : Compile next compiled word )
: [char] char tcall literal ; immediate compile-only ( --, <string> : )
\ h: ?quit command? if $38 literal -throw exit then ;
: ; ( ?quit ) ?check =exit , [ fallthrough; immediate compile-only
h: get-current! ?dup if get-current ! exit then ; ( -- wid )
: : align here dup last-def ! ( "name", -- colon-sys )
    last , token ?nul ?unique count + cp! $cafe literal ] ;
: begin here  ; immediate compile-only      ( -- a )
: until fallthrough; immediate compile-only  ( a -- )
h: jumpz, chars $2000 literal or , ;
: again fallthrough; immediate compile-only
h: jump, chars ( $0000 literal or ) , ;
h: here-0 here 0x0000 ;
: if here-0 jumpz, ; immediate compile-only
: then fallthrough; immediate compile-only
h: doThen  here chars over @ or swap! ;
: else here-0 jump, swap doThen ; immediate compile-only
: while tcall if ; immediate compile-only
: repeat swap tcall again tcall then ; immediate compile-only
h: last-cfa last-def @ cfa ;  ( -- u )
: recurse last-cfa compile, ; immediate compile-only
: tail last-cfa jump, ; immediate compile-only
: create tcall : drop compile doVar get-current ! [ ;
: >body cell+ ;
h: doDoes r> chars here chars last-cfa dup cell+ doLit ! , ;
: does> compile doDoes nop ; immediate compile-only
: variable create 0 literal , ;
: constant create [t] doConst literal make-callable here cell- ! , ;
: :noname here 0 literal $cafe literal ]  ;
: for =>r , here ; immediate compile-only
: next compile doNext , ; immediate compile-only
: aft drop here-0 jump, tcall begin swap ; immediate compile-only
: doer create =exit last-cfa ! =exit ,  ;
: make ( "name1", "name2", -- : make name1 do name2 )
  find-cfa find-cfa make-callable
  state@
  if
    tcall literal tcall literal compile ! nop exit
  then
  swap! ; immediate
: hide ( "name", -- : hide a given word from the search order )
  token find 0= if not-found exit then nfa $80 literal toggle ;

\ ## Strings 
\ The string word set is quite small, there are words already defined for
\ manipulating strings such 'c@', and 'count', but they are not exclusively
\ used for strings. These woulds will allow string literals to be embedded
\ within word definitions.
\ 
\ Forth uses counted strings, at least traditionally, which contain the string
\ length as the first byte of the string. This limits the string length to
\ 255 characters, which is enough for our small Forth but is quite limiting.
\ 
\ More modern Forths either use NUL terminated strings, or larger counts
\ for their counted strings. Both methods have trade-offs. 

\ NUL terminated strings allow for arbitrary lengths, and are often used by 
\ programs written in C, or built upon the C runtime, along with their 
\ libraries. NUL terminated strings cannot hold binary data however, and have 
\ an overhead for string length related operations.
\ 
\ Using a larger count prefix obviously allows for larger strings, but it
\ is not standard and new words would have to be written, or new conventions
\ followed, when dealing with these strings. For example the 'count' word can 
\ be used on the entire string if the string size is a single byte in size.
\ Another complication is how big should the length prefix be? 16, 32, or
\ 64-bit? This might depend on the intended use, the preferences of the
\ programmer, or what is most natural on the platform.
\ 
\ Another complication in modern string handling is UTF-8,
\ <https://en.wikipedia.org/wiki/UTF-8> and other character encoding schemes,
\ which is something to be aware of, but not a subject we will go in to.
\ 
\ The issues described only talk about problems with Forths representation
\ of strings, nothing has even been said about the difficulty of using them
\ for string heavy applications!
\ 
\ Only a few string specific words will be defined, for compiling string
\ literals into a word definition, and for returning an address to a compiled
\ string.

\ @todo Change order of program, this should be near '$"|' and '."|'

h: $,' [char] " word count + cp! ;              ( -- )
: $"  compile $"| $,' ; immediate compile-only ( <string>, --, Run: -- b )
: ."  compile ."| $,' ; immediate compile-only ( <string>, -- )
: abort [-1] (bye) ;                           ( -- )
h: {abort} do$ print cr abort ;                 ( -- )
: abort" compile {abort} $,' ; immediate compile-only \ "

\ ## Vocabulary Words 
\ The vocabulary word set should already be well understood, if the
\ metacompiler has been, the vocabulary word set is how Forth organizes words
\ and controls visibility of words.
\ 
\ 

h: find-empty-cell begin dup-@ while cell+ repeat ; ( a -- a )

: get-order ( -- widn ... wid1 n : get the current search order )
  context
  find-empty-cell
  dup cell- swap
  context - chars dup>r 1- dup 0< if $32 literal -throw exit then
  for aft dup-@ swap cell- then next @ r> ;

xchange _forth-wordlist root-voc

: forth-wordlist _forth-wordlist ;

: set-order ( widn ... wid1 n -- : set the current search order )
  dup [-1] = if drop root-voc 1 literal set-order exit then
  dup #vocs > if $31 literal -throw exit then
  context swap for aft tuck ! cell+ then next 0 literal swap! ;

: forth root-voc forth-wordlist  2 literal set-order ; ( -- )

\ The name fields length in a counted string is used to store a bit 
\ indicating the word is hidden. This is the highest bit in the count byte.
h: not-hidden? nfa c@ $80 literal and 0= ; ( pwd -- )
h: .words space 
    begin 
      dup 
    while dup not-hidden? if dup .id space then @address repeat drop cr ;
: words
  get-order begin ?dup while swap dup cr u. colon @ .words 1- repeat ;

xchange root-voc _forth-wordlist

: previous get-order swap drop 1- set-order ; ( -- )
: also get-order over swap 1+ set-order ;     ( wid -- )
: only [-1] set-order ;                       ( -- )
: order get-order for aft . then next cr ;    ( -- )
: anonymous get-order 1+ here 1 literal cells allot swap set-order ; ( -- )
: definitions context @ set-current ;         ( -- )
h: (order)                                      ( w wid*n n -- wid*n w n )
  dup if
    1- swap >r (order) over r@ xor
    if
      1+ r> -rot exit
    then rdrop
  then ;
: -order get-order (order) nip set-order ;                 ( wid -- )
: +order dup>r -order get-order r> swap 1+ set-order ;     ( wid -- )

: editor decimal editor-voc +order ; ( -- )
: assembler root-voc assembler-voc 2 literal set-order ;   ( -- )
: ;code assembler ; immediate                              ( -- )
: code tcall : assembler ;                                       ( -- )

xchange _forth-wordlist assembler-voc
: end-code forth tcall ; ; immediate ( -- )
xchange assembler-voc _forth-wordlist

\ ## Block Word Set
\ The block word set abstracts out how access to mass storage works in just
\ a handful of words. The main word is 'block', with the words 'update',
\ 'flush' and the variable 'blk' also integral to the working of the block
\ word set. All of the other words can be implemented upon these.
\ 
\ Block storage is an outdated, but simple, method of accessing
\ mass storage that demands little from the hardware or the system it is
\ implemented under, just that data can be transfered from memory to disk
\ somehow. It has no requirements that there be a file system, which is
\ perfect for embedded devices as well as upon the microcomputers it
\ originated on.
\ 
\ A 'Forth block' is 1024 byte long buffer which is backed by a mass
\ storage device, which we will refer to as 'disk'. Very compact programs
\ can be written that have their data stored persistently. Source can
\ and data can be stored in blocks and evaluated, which will be described
\ more in the 'Block editor' section of this document.
\ 
\ The 'block' word does most of the work. The way it is usually implemented
\ is as follows:
\ 
\ 1. A user provides a block number to the 'block' word. The block
\ number is checked to make sure it is valid, and an exception is thrown
\ if it is not.
\ 2. If the block if already loaded into a block buffer from disk, the
\ address of the memory it is loaded into is returned.
\ 3. If it was not, then 'block' looks for a free block buffer, loads
\ the 1024 byte section off disk into the block buffer and returns an
\ address to that.
\ 4. If there are no free block buffers then it looks for a block buffer
\ that is marked as being dirty with 'update' (which marks the previously
\ loaded block as being dirty when called), then transfers that dirty block
\ to disk. Now that there is a free block buffer, it loads the data that
\ the user wants off of disk and returns a pointer to that, as in the
\ previous bullet point. If none of the buffers are marked as dirty then
\ then any one of them could be reused - they have not been marked as being
\ modified so their contents could be retrieved off of disk if needed.
\ 5. Under all cases, before the address of the loaded block has been
\ returned, the variable 'blk' is updated to contain the latest loaded
\ block.
\ 
\ This word does a lot, but is quite simple to use. It implements a simple
\ cache where data is transfered back to disk only if needed, and multiple
\ sections of memory from disk can be loaded into memory at the same time.
\ The mechanism by which this happens is entirely hidden from the user.
\ 
\ This Forth implements 'block' in a slightly different way. The entire
\ virtual machine image is loaded at start up, and can be saved back to
\ disk (or small sections of it) with the "(save)" instruction. 'update'
\ marks the entire image as needing to be saved back to disk, whilst
\ 'flush' calls "(save)". 'block' then only has to check the block number
\ is within range, and return a pointer to the block number multiplied by
\ the size of a block - so this means that this version of 'block' is just
\ an index into main memory. This is similar to how 'colorForth' implements
\ its block word.
\ 
: update [-1] block-dirty ! ;    ( -- )
h: blk-@ blk @ ;                  ( -- k : retrieve current loaded block )
h: +block blk-@ + ;               ( -- )
: save 0 literal here (save) throw ; ( -- : save blocks )
: flush block-dirty @ if 0 literal [-1] (save) throw exit then ; ( -- )

: block ( k -- a )
  1depth
  dup $3f literal u> if $23 literal -throw exit then
  dup blk !
  $a literal lshift ( <-- b/buf * ) ;

\ The block word set has the following additional words, which augment the
\ set nicely, they are 'list', 'load' and 'thru'. The 'list' word is used
\ for displaying the contents of a block, it does this by splitting the
\ block into 16 lines each, 64 characters long. 'load' evaluates a given
\ block, and 'thru' evaluates a range of blocks.
\ 
\ This is how source code was stored and evaluated during the microcomputer
\ era, as opposed to storing the source in named byte stream oriented files 
\ as is common nowadays. 
\ 
\ It is more difficult, but possible, to store and edit source code in this
\ manner, but it requires that the programmer(s) follow certain conventions
\ when editing blocks, both in how programs are split up, and how they are
\ formatted.
\ 
\ A block shown with 'list' might look like the following: 
\ 
\ 	   ----------------------------------------------------------------
\ 	 0|( Simple Math Routines 31/12/1989 RJH 3/4                #20  ) |
\ 	 1|                                                                |
\ 	 2|: square dup * ; ( u -- u )                                     |
\ 	 3|: sum-of-squares square swap square + ; ( u u -- u )            |
\ 	 4|: even 1 and 0= ; ( u -- b )                                    |
\ 	 5|: odd even 0= ;   ( u -- b )                                    |
\ 	 6|                                                                |
\ 	 7|                                                                |
\ 	 8|                                                                |
\ 	 9|                                                                |
\ 	10|                                                                |
\ 	11|                                                                |
\ 	12|                                                                |
\ 	13|                                                                |
\ 	14|                                                                |
\ 	15|                                                                |
\ 	   ----------------------------------------------------------------
\ 
\ Longer comments for a source code block were stored in a 'shadow block', 
\ which is only enforced by convention. One possible convention is to store
\ the source in even numbered blocks, and the comments in the odd numbered
\ blocks.
\ 
\ By storing a comment in the first line of a block a word called 'index'
\ could be used to make a table of contents all of the blocks available on
\ disk, 'index' simply displays the first line of each block within a block
\ range. 

\ The common theme is that convention is key to successfully using blocks.
\
\ @todo Rewrite this section
\ Blocks could also be used to store error messages, a word called 'message'
\ is available on some old Forths which when given an error code (say -8)
\ loads the block containing error messages and prints off that line. The 
\ errors messages would be located in a block range that 'message' would know 
\ about, for example blocks 4-8. This means RAM or program storage is not 
\ used for storing error messages - a useful feature in memory starved systems. 
\ It does not matter that access to the disk would be relatively slow, the 
\ error messages are only displayed in exceptional circumstances. This is an
\ example of the block storage being used as crude database.
\ 
h: c/l* ( c/l * ) 6 literal lshift ; ( u -- u )
h: c/l/ ( c/l / ) 6 literal rshift ; ( u -- u )
h: line swap block swap c/l* + c/l ; ( k u -- a u )
h: loadline line evaluate ;          ( k u -- )
: load 0 literal l/b 1- for 2dup 2>r loadline 2r> 1+ next 2drop ; ( k -- )
h: pipe $7c literal emit ;           ( -- )
\ h: .line line -trailing $type ;    ( k u -- )
h: .border 3 literal spaces c/l $2d literal nchars cr ; ( -- )
h: #line dup 2 literal u.r ;         ( u -- u : print line number )
: thru over- for dup load 1+ next drop ; ( k1 k2 -- )
: blank =bl fill ;                  ( b u -- )
\ t: message l/b extract .line cr ;  ( u -- )
h: retrieve block drop ;             ( k -- )
: list
  dup retrieve
  cr
  .border
  0 literal begin
    dup l/b <
  while
    2dup #line pipe line $type pipe cr 1+
  repeat .border 2drop ; ( k -- )

\ t: index ( k1 k2 -- : show titles for block k1 to k2 )
\  over- cr
\  for
\    dup 5u.r space pipe space dup 0 literal .line cr 1+
\  next drop ;

\ ## Booting
\ We are now nearing the end of this tutorial, after the boot sequence
\ word set has been completed we will have a working Forth system. The
\ boot sequence consists of getting the Forth system into a known working
\ state, checking for corruption in the image, and printing out a welcome
\ message. This behaviour can be changed if needed.
\ 
\ The boot sequence is as follows:
\ 
\ 1. The virtual machine starts execution at address 0 which will be set
\ to point to the word 'boot-sequence'.
\ 2. The word 'boot-sequence' is executed, which will run the word 'cold'
\ to perform the system setup.
\ 3. The word 'cold' checks that the image length and CRC in the image header
\ match the values it calculates, zeros blocks of memory, and initializes the
\ systems I/O. 
\ 4. 'boot-sequence' continues execution by executing the execution token
\ stored in the variable 'boot'. This is set to 'normal-running' by default.
\ 5. 'normal-running' prints out the welcome message by calling the word 'hi',
\ and then entering the Forth Read-Evaluate Loop, known as 'quit'. This should
\ not normally return.
\ 6. If the function returns, 'bye' is called, halting the virtual machine.
\ 
\ The boot sequence is modifiable by the user by either writing an execution
\ token to the 'boot' variable, or by writing to a jump to a word into memory
\ location zero, if the image is saved, the next time it is run execution will
\ take place at the new location.
\ 
\ It should be noted that the self-check routine, 'bist', disables checking
\ in generated images by manipulating the word header once the check has
\ succeeded. 

\ @todo Talk about 'encryption' or obfuscation, and decompressing the image
\ on the fly.
\ @todo Disable CRC check with a bit in the image header, instead of by
\ zeroing the CRC.

\ 'bist' checks the length field in the header matches 'here' and that the
\ CRC in the header matches the CRC it calculates in the image, it has to
\ zero the CRC field out first.
h: bist ( -- u : built in self test )
  header-crc @ 0 literal = if 0x0000 exit then ( exit if CRC was zero )
  header-length @ here xor if 2 literal exit then ( length check )
  header-crc @ 0 literal header-crc !   ( retrieve and zero CRC )
  0 literal here crc xor if 3 literal exit then 0x0000 ;

: cold ( -- : cold boot )
   bist ?dup if negate (bye) exit then
   $10 literal block b/buf 0 literal fill
   $12 literal retrieve io! 
   forth sp0 sp! ;

h: hi hex cr ."| $literal eFORTH V " ver 0 literal u.r cr here . .free cr [ ;
h: normal-running hi quit ;               ( -- : boot word )
h: boot-sequence cold boot @execute bye ; ( -- : perform the boot sequence )

\ ## See : The Forth Disassembler

\ @warning This disassembler is experimental, and not liable to work
\ @todo improve this with better output and exit detection.
\ 'see' could be improved with a word that detects when the end of a
\ word actually occurs, and with a disassembler for instructions. The output
\ could also be better formatted, or optionally made to be more or less
\ verbose. Another improvement would be to do the word lookup for branches
\ that occur outside of the word definition, or prior to it, as there
\ are many words which have been turned into tail calls - or a single
\ branch.

\ @todo handle various special cases in the decompiler 
\ Such as literals spanning two instructions, merged exits, tail calls, 
\ variables, constants, created words, strings and possibly more.

h: validate tuck cfa <> if drop-0 exit then nfa ; ( cfa pwd -- nfa | 0 )

h: search-for-cfa ( wid cfa -- nfa : search for CFA in a word list )
  address cells >r
  begin
    dup
  while
    address dup r@ swap dup-@ address swap within ( simplify? )
    ( @bug does not continue with search if validate fails )
    if @address r> swap validate exit then 
    address @
  repeat rdrop ;

h: name ( cwf -- a | 0 )
   >r
   get-order 
   begin 
     dup 
   while 
     swap r@ search-for-cfa ?dup if >r 1- ndrop r> rdrop exit then 
   1- repeat rdrop ;

h: .name name ?dup 0= if $"| $literal ??? " then print ;
h: ?instruction ( i m e -- i 0 | e -1 )
   >r over and r> tuck = if nip [-1] exit then drop-0 ;

h: .instruction
   0x8000        0x8000        ?instruction if ."| $literal LIT " exit then
   $6000 literal $6000 literal ?instruction if ."| $literal ALU " exit then
   $6000 literal $4000 literal ?instruction if ."| $literal CAL " exit then
   $6000 literal $2000 literal ?instruction if ."| $literal BRZ " exit then
   drop 0 literal ."| $literal BRN " ;

: decompile ( u -- : decompile instruction )
   dup .instruction $4000 literal =
   if space .name exit then drop ;

h: decompiler ( previous current -- : decompile starting at address )
  >r
   begin dup r@ u< while
     dup 5u.r colon
     dup-@
     dup 5u.r space decompile cr cell+
   repeat rdrop drop ;

\ 'see' is the Forth disassembler, it takes a word and (attempts) to 
\ turn it back into readable Forth source code. The disassembler is only
\ a few hundred bytes in size, which is a testament to the brevity achievable
\ with Forth.
\ 
\ If the word 'see' was good enough we could potentially dispense with the
\ source code entirely: the entire dictionary could be disassembled and saved
\ to disk, modified, then recompiled yielding a modified Forth. Although 
\ comments would not be present, meaning this would be more of an intellectual
\ exercise than of any utility.

: see ( --, <string> : decompile a word )
  token finder 0= if not-found exit then
  swap 2dup= if drop here then >r
  cr colon space dup .id space dup
  cr
  cfa r> decompiler space $3b literal emit
  dup compile-only? if ."| $literal  compile-only  " then 
  dup inline?       if ."| $literal  inline  "       then
      immediate?    if ."| $literal  immediate  "    then cr ;

\ A few useful utility words will be added next, which are not strictly 
\ necessary but are useful. Those are '.s' for examining the contents of the 
\ variable stack, and 'dump' for showing the contents of a section of memory
\ 
\ The '.s' word must be careful not to alter that variable stack whilst
\ trying to print it out. It uses the word 'pick' to achieve this, otherwise
\ there is nothing special about this word, and it is very useful for
\ debugging code interactively to see what its stack effects are.
\ 
\ The dump keyword is fairly useful for the implementer so that they can
\ use Forth to debug if the compilation is working, or if a new word
\ is producing the correct assembly. It can also be used as a utility to
\ export binary sections of memory as text. 
\ 
\ The programmer might want to edit the 'dump' word to customize its output,
\ the addition of the 'dc+' word is one way it could be extended, which is
\ commented out below. Like 'dm+', 'dc+' operates on a single line to
\ be displayed, however 'dc+' decompiles the memory into human readable
\ instructions instead of numbers, unfortunately the lines it produces are
\ too long.
\ 
\ Normally the word 'dump' outputs the memory contents in hexadecimal,
\ however a design decision was taken to output the contents of memory in
\ what the current numeric output base is instead. This makes the word
\ more flexible, more consistent and shorter, than it otherwise would be as
\ the current output base would have to be saved and then restored.
\ 

: .s cr depth for aft r@ pick . then next ."| $literal  <sp " ; ( -- )
h: dm+ chars for aft dup-@ space 5u.r cell+ then next ; ( a u -- a )
\ h: dc+ chars for aft dup-@ space decompile cell+ then next ; ( a u -- a )
\ @todo Use '\\' to comment out code

: dump ( a u -- )
  $10 literal + \ align up by dump-width
  4 literal rshift ( <-- equivalent to "dump-width /" )
  for
    aft
      cr dump-width 2dup
      over 5u.r colon space
      dm+ ( dump-width dc+ ) \ <-- dc+ is optional
      -rot
      2 literal spaces $type
    then
  next drop ;

\ The standard Forth dictionary is now complete, but the variables containing
\ the word list need to be updated a final time. The next section implements
\ the block editor, which is in the 'editor' word set. Their are two variables
\ that need updating, '_forth-wordlist', a vocabulary we have already
\ encountered. An 'current', which contains a pointer to a word list, this
\ word list is the one new definitions (defined by ':', or 'create') are
\ added to. It will be set to '_forth-wordlist' so new definitions are added
\ to the default vocabulary.
[last]              [t] _forth-wordlist t!
[t] _forth-wordlist [t] current         t!

\ ## Block Editor
\ This block editor is an excellent example of a Forth application; it is
\ small, terse, and uses the facilities already built into Forth to do all
\ of the heavy lifting, specifically vocabularies, the block word set and
\ the text interpreter.
\ 
\ Forth blocks used to be the canonical way of storing both source code and
\ data within a Forth system, it is a simply way of abstracting out how mass
\ storage works and worked well on the microcomputers available in the 1980s.
\ With the rise of computers with a more capable operating system the Block
\ Word Set (See <https://www.taygeta.com/forth/dpans7.htm>) fell out of 
\ favour, being replaced instead by the File Access Word Set 
\ (See <https://www.taygeta.com/forth/dpans11.htm>), allowing named files
\ to be accessed as a byte stream.
\ 
\ To keep things simple this editor uses the block word set and in typical
\ Forth fashion simplifies the problem to the extreme, whilst also sacrificing
\ usability and functionally - the block editor allows for the editing of
\ programs but it is more difficult and more limited than traditional editors.
\ It has no spell checking, or syntax highlighting, and does little in the
\ way of error checking. But it is very small, compact, easy to understand, and
\ if needed could be extended.
\ 
\ The way this editor works is by replacing the current search order with
\ a set of words that implement text editing on the currently loaded block,
\ as well as managing what block is loaded. The defined words are short,
\ often just a single letter long. 
\ 
\ The act of editing text is simplified as well, instead of keeping track of 
\ variable width lines of text and files, a single block (1024 characters) is 
\ divided up into 16 lines, each 64 characters in length. This is the essence
\ of Forth, radically simplifying the problem from all possible angels; the
\ algorithms used, the software itself and where possible the hardware. Not
\ every task can be approached this way, nor would everyone be happy with
\ the results, the editor being presented more as a curiosity than anything
\ else.
\ 
\ We have a way of loading and saving data from disks (the 'block', 'update' 
\ and 'flush' words) as well as a way of viewing the data  in a block (the 
\ 'list' word) and evaluating the text within a block (with the 'load' word). 
\ The variable 'blk' is also of use as it holds the latest block we have 
\ retrieved from disk. By defining a new word set we can skip the part of 
\ reading in a parsing commands and numbers, we can use text interpreter and 
\ line oriented input to do the work for us, as discussed. 
\ 
\ Only one extra word is actually need given the words we already have, one
\ which can destructively replace a line starting at a given column in the
\ currently loaded block. All of the other commands are simple derivations
\ of existing words. This word is called 'ia', short for 'insert at', which
\ takes two numeric arguments (starting line as the first, and column as the
\ second) and reads all text on the line after the 'ia' and places it at the
\ specified line/column.
\ 
\ The command description and their definitions are the best descriptions
\ of how this editor works. Try to use the word set interactively to get
\ a feel for it:
\ 
\ | A1 | A2 | Command |                Description                 |
\ | -- | -- | ------- | ------------------------------------------ |
\ | #2 | #1 |  ia     | insert text into column #1 on line #2      |
\ |    | #1 |  i      | insert text into column  0 on line #1      |
\ |    | #1 |  b      | load block number #1                       |
\ |    | #1 |  d      | blank line number #1                       |
\ |    |    |  x      | blank currently loaded block               |
\ |    |    |  l      | redisplay currently loaded block           |
\ |    |    |  q      | remove editor word set from search order   |
\ |    |    |  n      | load next block                            |
\ |    |    |  p      | load previous block                        |
\ |    |    |  s      | save changes to disk                       |
\ |    |    |  e      | evaluate block                             |
\ 
\ An example command session might be:
\ 
\ | Command Sequence         | Description                             |
\ | ------------------------ | --------------------------------------- |
\ | editor                   | add the editor word set to search order |
\ | $20 b l                  | load block $20 (hex) and display it     |
\ | x                        | blank block $20                         |
\ | 0 i .( Hello, World ) cr | Put ".( Hello, World ) cr" on line 0    |
\ | 1 i 2 2 + . cr           | Put "2 2 + . cr" on line 1              |
\ | l                        | list block $20 again                    |
\ | e                        | evaluate block $20                      |
\ | s                        | save contents                           |
\ | q                        | unload block word set                   |
\ 
\ See: <http://retroforth.org/pages/?PortsOfRetroEditor> for the origin of
\ this block editor, and for different implementations.

0 tlast s!
h: [block] blk-@ block ;       ( k -- a : loaded block address )
h: [check] dup b/buf c/l/ u>= if $18 literal -throw exit then ;
h: [line] [check] c/l* [block] + ; ( u -- a )
: b retrieve ;                ( k -- )
: l blk-@ list ;              ( -- )
: n  1 literal +block b l ;   ( -- : load and list next block )
: p [-1] +block b l ;         ( -- : load and list previous block )
: d [line] c/l blank ;        ( u -- : delete line )
: x [block] b/buf blank ;     ( -- : erase loaded block )
: s update flush ;            ( -- : flush changes to disk )
: q editor-voc -order ; ( -- : quit editor )
: e q blk-@ load editor ;     ( -- : evaluate block )
: ia c/l* + [block] + source drop in@ + ( u u -- )
   swap source nip in@ - cmove [t] \ tcompile, ;
: i 0 literal swap ia ;           ( u -- )
\ : u update ;                ( -- : set block set as dirty )
\ : w words ;
\ : yank pad c/l ; 
\ : c [line] yank >r swap r> cmove ;
\ : y [line] yank cmove ;
\ : ct swap y c ;
\ : ea [line] c/l evaluate ;
\ : sw 2dup y [line] swap [line] swap c/l cmove c ;
[last] [t] editor-voc t! 0 tlast s!

\ ## Final Touches

there           [t] cp t!
[t] boot-sequence 2/ 0 t! ( set starting word )
[t] normal-running [u] boot t!

there    6 tcells t! \ Set Length First!
checksum 7 tcells t! \ Calculate image CRC

finished
bye

# APPENDIX

## The Virtual Machine

The Virtual Machine is a 16-bit stack machine based on the [H2 CPU][], a
derivative of the [J1 CPU][], but adapted for use on a computer.

Its instruction set allows for a fairly dense encoding, and the project
goal is to be fairly small whilst still being useful.  It is small enough
that is should be easily understandable with little explanation, and it
is hackable and extensible by modification of the source code.

## Virtual Machine Memory Map

There is 64KiB of memory available to the Forth virtual machine, of which only
the first 16KiB can contain program instructions (or more accurately branch
locations can only be in the first 16KiB of memory). The virtual machine memory
can divided into three regions of memory, the applications further divide the
memory into different sections.

| Block   |  Region          |
| ------- | ---------------- |
| 0 - 15  | Program Storage  |
| 16      | User Data        |
| 17      | Variable Stack   |
| 18 - 62 | User data        |
| 63      | Return Stack     |

Program execution begins at address zero. The variable stack starts at the
beginning of block 17 and grows upwards, the return stack starts at the end of
block 63 and grows downward.

## Instruction Set Encoding

For a detailed look at how the instructions are encoded the source code is the
definitive guide, available in the file [forth.c][].

A quick overview:

	+---------------------------------------------------------------+
	| F | E | D | C | B | A | 9 | 8 | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
	+---------------------------------------------------------------+
	| 1 |                    LITERAL VALUE                          |
	+---------------------------------------------------------------+
	| 0 | 0 | 0 |            BRANCH TARGET ADDRESS                  |
	+---------------------------------------------------------------+
	| 0 | 0 | 1 |            CONDITIONAL BRANCH TARGET ADDRESS      |
	+---------------------------------------------------------------+
	| 0 | 1 | 0 |            CALL TARGET ADDRESS                    |
	+---------------------------------------------------------------+
	| 0 | 1 | 1 |   ALU OPERATION   |T2N|T2R|N2T|R2P| RSTACK| DSTACK|
	+---------------------------------------------------------------+
	| F | E | D | C | B | A | 9 | 8 | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
	+---------------------------------------------------------------+

	T   : Top of data stack
	N   : Next on data stack
	PC  : Program Counter

	LITERAL VALUES : push a value onto the data stack
	CONDITIONAL    : BRANCHS pop and test the T
	CALLS          : PC+1 onto the return stack

	T2N : Move T to N
	T2R : Move T to top of return stack
	N2T : Move the new value of T (or D) to N
	R2P : Move top of return stack to PC

	RSTACK and DSTACK are signed values (twos compliment) that are
	the stack delta (the amount to increment or decrement the stack
	by for their respective stacks: return and data)

### ALU Operations

The ALU can be programmed to do the following operations on an ALU instruction,
some operations trap on error (U/MOD, /MOD).

|  #  | Mnemonic | Description          |
| --- | -------- | -------------------- |
|  0  | T        | Top of Stack         |
|  1  | N        | Copy T to N          |
|  2  | R        | Top of return stack  |
|  3  | T@       | Load from address    |
|  4  | NtoT     | Store to address     |
|  5  | T+N      | Double cell addition |
|  6  | T\*N     | Double cell multiply |
|  7  | T&N      | Bitwise AND          |
|  8  | TorN     | Bitwise OR           |
|  9  | T^N      | Bitwise XOR          |
| 10  | ~T       | Bitwise Inversion    |
| 11  | T--      | Decrement            |
| 12  | T=0      | Equal to zero        |
| 13  | T=N      | Equality test        |
| 14  | Nu&lt;T  | Unsigned comparison  |
| 15  | N&lt;T   | Signed comparison    |
| 16  | NrshiftT | Logical Right Shift  |
| 17  | NlshiftT | Logical Left Shift   |
| 18  | SP@      | Depth of stack       |
| 19  | RP@      | R Stack Depth        |
| 20  | SP!      | Set Stack Depth      |
| 21  | RP!      | Set R Stack Depth    |
| 22  | SAVE     | Save Image           |
| 23  | TX       | Get byte             |
| 24  | RX       | Send byte            |
| 25  | U/MOD    | u/mod                |
| 26  | /MOD     | /mod                 |
| 27  | BYE      | Return               |

### Encoding of Forth Words

Many Forth words can be encoded directly in the instruction set, some of the
ALU operations have extra stack and register effects as well, which although
would be difficult to achieve in hardware is easy enough to do in software.

| Word   | Mnemonic | T2N | T2R | N2T | R2P |  RP |  SP |
| ------ | -------- | --- | --- | --- | --- | --- | --- |
| dup    | T        | T2N |     |     |     |     | +1  |
| over   | N        | T2N |     |     |     |     | +1  |
| invert | ~T       |     |     |     |     |     |     |
| um+    | T+N      |     |     |     |     |     |     |
| \+     | T+N      |     |     | N2T |     |     | -1  |
| um\*   | T\*N     |     |     |     |     |     |     |
| \*     | T\*N     |     |     | N2T |     |     | -1  |
| swap   | N        | T2N |     |     |     |     |     |
| nip    | T        |     |     |     |     |     | -1  |
| drop   | N        |     |     |     |     |     | -1  |
| exit   | T        |     |     |     | R2P |  -1 |     |
| &gt;r  | N        |     | T2R |     |     |   1 | -1  |
| r&gt;  | R        | T2N |     |     |     |  -1 |  1  |
| r@     | R        | T2N |     |     |     |     |  1  |
| @      | T@       |     |     |     |     |     |     |
| !      | NtoT     |     |     |     |     |     | -1  |
| rshift | NrshiftT |     |     |     |     |     | -1  |
| lshift | NlshiftT |     |     |     |     |     | -1  |
| =      | T=N      |     |     |     |     |     | -1  |
| u&lt;  | Nu&lt;T  |     |     |     |     |     | -1  |
| &lt;   | N&lt;T   |     |     |     |     |     | -1  |
| and    | T&N      |     |     |     |     |     | -1  |
| xor    | T^N      |     |     |     |     |     | -1  |
| or     | T|N      |     |     |     |     |     | -1  |
| sp@    | SP@      | T2N |     |     |     |     |  1  |
| sp!    | SP!      |     |     |     |     |     |     |
| 1-     | T--      |     |     |     |     |     |     |
| rp@    | RP@      | T2N |     |     |     |     |  1  |
| rp!    | RP!      |     |     |     |     |     | -1  |
| 0=     | T=0      |     |     |     |     |     |     |
| nop    | T        |     |     |     |     |     |     |
| (bye)  | BYE      |     |     |     |     |     |     |
| rx?    | RX       | T2N |     |     |     |     |  1  |
| tx!    | TX       |     |     | N2T |     |     | -1  |
| (save) | SAVE     |     |     |     |     |     | -1  |
| u/mod  | U/MOD    | T2N |     |     |     |     |     |
| /mod   | /MOD     | T2N |     |     |     |     |     |
| /      | /MOD     |     |     |     |     |     | -1  |
| mod    | /MOD     |     |     | N2T |     |     | -1  |
| rdrop  | T        |     |     |     |     |  -1 |     |

## Interaction

The outside world can be interacted with in two ways, with single character
input and output, or by saving the current Forth image. The interaction is
performed by three instructions.

## eForth

The interpreter is based on eForth by C. H. Ting, with some modifications
to the model.

## eForth Memory model

The eForth model imposes extra semantics to certain areas of memory.

| Address       | Block  | Meaning                        |
| ------------- | ------ | ------------------------------ |
| $0000         |   0    | Start of execution             |
| $0002         |   0    | Trap Handler                   |
| $0004-EOD     |   0    | The dictionary                 |
| EOD-PAD1      |   ?    | Compilation and Numeric Output |
| PAD1-PAD2     |   ?    | Pad Area                       |
| PAD2-$3FFF    |   15   | End of dictionary              |
| $4000         |   16   | Interpreter variable storage   |
| $4400         |   17   | Start of variable stack        |
| $4800-$FBFF   | 18-63  | Empty blocks for user data     |
| $FC00-$FFFF   |   0    | Return stack block             |

## Error Codes

This is a list of Error codes, not all of which are used by the application.

| Hex  | Dec  |  Message                                      |
| ---- | ---- | --------------------------------------------- |
| FFFF |  -1  | ABORT                                         |
| FFFE |  -2  | ABORT"                                        |
| FFFD |  -3  | stack overflow                                |
| FFFC |  -4  | stack underflow                               |
| FFFB |  -5  | return stack overflow                         |
| FFFA |  -6  | return stack underflow                        |
| FFF9 |  -7  | do-loops nested too deeply during execution   |
| FFF8 |  -8  | dictionary overflow                           |
| FFF7 |  -9  | invalid memory address                        |
| FFF6 | -10  | division by zero                              |
| FFF5 | -11  | result out of range                           |
| FFF4 | -12  | argument type mismatch                        |
| FFF3 | -13  | undefined word                                |
| FFF2 | -14  | interpreting a compile-only word              |
| FFF1 | -15  | invalid FORGET                                |
| FFF0 | -16  | attempt to use zero-length string as a name   |
| FFEF | -17  | pictured numeric output string overflow       |
| FFEE | -18  | parsed string overflow                        |
| FFED | -19  | definition name too long                      |
| FFEC | -20  | write to a read-only location                 |
| FFEB | -21  | unsupported operation                         |
| FFEA | -22  | control structure mismatch                    |
| FFE9 | -23  | address alignment exception                   |
| FFE8 | -24  | invalid numeric argument                      |
| FFE7 | -25  | return stack imbalance                        |
| FFE6 | -26  | loop parameters unavailable                   |
| FFE5 | -27  | invalid recursion                             |
| FFE4 | -28  | user interrupt                                |
| FFE3 | -29  | compiler nesting                              |
| FFE2 | -30  | obsolescent feature                           |
| FFE1 | -31  | &gt;BODY used on non-CREATEd definition       |
| FFE0 | -32  | invalid name argument (e.g., TO xxx)          |
| FFDF | -33  | block read exception                          |
| FFDE | -34  | block write exception                         |
| FFDD | -35  | invalid block number                          |
| FFDC | -36  | invalid file position                         |
| FFDB | -37  | file I/O exception                            |
| FFDA | -38  | non-existent file                             |
| FFD9 | -39  | unexpected end of file                        |
| FFD8 | -40  | invalid BASE for floating point conversion    |
| FFD7 | -41  | loss of precision                             |
| FFD6 | -42  | floating-point divide by zero                 |
| FFD5 | -43  | floating-point result out of range            |
| FFD4 | -44  | floating-point stack overflow                 |
| FFD3 | -45  | floating-point stack underflow                |
| FFD2 | -46  | floating-point invalid argument               |
| FFD1 | -47  | compilation word list deleted                 |
| FFD0 | -48  | invalid POSTPONE                              |
| FFCF | -49  | search-order overflow                         |
| FFCE | -50  | search-order underflow                        |
| FFCD | -51  | compilation word list changed                 |
| FFCC | -52  | control-flow stack overflow                   |
| FFCB | -53  | exception stack overflow                      |
| FFCA | -54  | floating-point underflow                      |
| FFC9 | -55  | floating-point unidentified fault             |
| FFC8 | -56  | QUIT                                          |
| FFC7 | -57  | exception in sending or receiving a character |
| FFC6 | -58  | [IF], [ELSE], or [THEN] exception             |


## To Do / Wish List

* Documentation of the project, some words, and the instruction set, as well as
the memory layout
* To facilitate porting to microcontrollers the Forth could be made to be
stored in a ROM, with initial variable values copied to RAM, the virtual
machine would also have to be modified to map different parts of the address
space into RAM and ROM. This would allow the system to require very little
(~2-4KiB) of RAM for a usable system, with a 6KiB ROM.
* Relative jumps could be used instead of absolute jumps in the code, this
would make relocation easier, and could make all code position independent. It
may also make the resulting code easier to compress, especially if the 
majority of jumps are to near locations. Perhaps relative addressing should
only be used for branches and not calls, or vice versa. Absolute jumps could
be faked if needed with the correct wordset, self modifying code, or the
correct compliation methods.
* Different ways of compressing the core file, and image self extractions,
should be investigated; [LZSS][], [Run Length Encoding][], [Huffman][] and 
[Adaptive Huffman][] encoding could be implemented in Forth and in the 
meta-compiler so an image can be self-extracted on the fly.
* Routines written in Forth for memory allocation, a soft floating point
library, and a 16-bit metacompiler for the [8086][]/[DOS][] would be useful.
* A method for obfuscating the produced image could be made, perhaps by
xoring the image with a known constant. A trivial obfuscation, obviously. Or
'encrypting' against the output of a Pseudo Random Number Generator for extra 
marks.
* On the Windows platform the input and output streams should be reopened in
binary mode.
* More assertions and range checks should be added to the interpreter, for
example the **save** function needs checks for bounds.
* The forth virtual machine in [forth.c][] should be made to be crash proof,
with checks to make sure indices never go out of bounds.
* Documentation could be extracted from the [meta.fth][] file, which should
describe the entire system: The metacompiler, the target virtual machine,
and how Forth works.
* Add more references, and turn this program into a literate file.
   - Compression routines would be a nice to have feature for reducing
   the saved image size. LZSS could be used, see:
   <https://oku.edu.mie-u.ac.jp/~okumura/compression/lzss.c>
   Adaptive Huffman encoding performs even better.
   - Talk about and write about:
     - Potential additions
     - The philosophy of Forth
     - How the meta compiler words
     - Implementing allocation routines, and floating point routines
     - Compression and the similarity of Forth Factoring and LZW compression
* This Forth needs a series of unit tests to make sure the basic functionality
of all the words is correct
* This Forth lacks a version of 'FORGET', as well as 'MARKER', which is
unfortunate, as they are useful. This is due to how word lists are
implemented.
* One possible exercise would be to reduce the image size to its absoluate
minimum, by removing unneeded functionality for the metacompilation process,
such as the block editor, and 'see', as well as any words not actually used
in the metacompilation process.
* Floating point routines can be found from here:
<http://codebase64.org/doku.php?id=base:floating_point_routines_for_the_6502>,
which will need adapting.
* Separating out the word header from the word definition would have a few
advantages; less code space would be used, 'fallthrough' would not just be
a special case for the metacompiler, 'FORGET' would be easier to implement,
and the headers for all words could be saved (so 'see' would work better).
* An image could be prepared with the smallest possible Forth interpreter,
it would not necessarily have to be able to meta-compile.
* Look at the libforth test bench and reimplement it
* Allow an arbitrary character to be used for numeric output alignment, not
just spaces. This would allow leading zeros to be added to numbers.

* Some more words need adding in, like "postpone", "[']", "[if]", "[else]",
"[then]", "T{", "}T", ...

: [[ ;     \ Stop postponing
: ]]
  begin
    >in @ ' ['] [[ <>
  while
    >in ! postpone postpone
  repeat
  drop ; immediate 

## Virtual Machine Implementation in C

/** @file      forth.c
 *  @brief     Forth Virtual Machine
 *  @copyright Richard James Howe (2017)
 *  @license   MIT */

#include <assert.h>
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define CORE (65536u)  /* core size in bytes */
#define SP0  (8704u)   /* Variable Stack Start: 8192 (end of program area) + 512 (block size) */
#define RP0  (32767u)  /* Return Stack Start: end of CORE in words */

#ifdef TRON
#define TRACE(PC,I,SP,RP) \
	fprintf(stderr, "%04x %04x %04x %04x\n", (unsigned)(PC), (unsigned)(I), (unsigned)(SP), (unsigned)(RP));
#else
#define TRACE(PC, I, SP, RP)
#endif

typedef uint16_t uw_t;
typedef int16_t  sw_t;
typedef uint32_t ud_t;

typedef struct {
	uw_t pc, t, rp, sp, core[CORE/sizeof(uw_t)];
} forth_t;

static FILE *fopen_or_die(const char *file, const char *mode)
{
	FILE *f = NULL;
	errno = 0;
	assert(file && mode);
	if(!(f = fopen(file, mode))) {
		fprintf(stderr, "failed to open file '%s' (mode %s): %s\n", file, mode, strerror(errno));
		exit(EXIT_FAILURE);
	}
	return f;
}

static int binary_memory_load(FILE *input, uw_t *p, const size_t length)
{
	assert(input && p && length <= 0x8000);
	for(size_t i = 0; i < length; i++) {
		const int r1 = fgetc(input);
		const int r2 = fgetc(input);
		if(r1 < 0 || r2 < 0)
			return -1;
		p[i] = (((unsigned)r1 & 0xffu))|(((unsigned)r2 & 0xffu) << 8u);
	}
	return 0;
}

static int binary_memory_save(FILE *output, uw_t *p, const size_t start, const size_t length)
{
	assert(output && p /* && ((start + length) < 0x8000 || (start > length))*/);
	for(size_t i = start; i < length; i++) {
		errno = 0;
		const int r1 = fputc((p[i])       & 0xff, output);
		const int r2 = fputc((p[i] >> 8u) & 0xff, output);
		if(r1 < 0 || r2 < 0) {
			fprintf(stderr, "write failed: %s\n", strerror(errno));
			return -1;
		}
	}
	return 0;
}

int load(forth_t *h, const char *name)
{
	assert(h && name);
	FILE *input = fopen_or_die(name, "rb");
	const int r = binary_memory_load(input, h->core, CORE/sizeof(uw_t));
	fclose(input);
	h->pc = 0; h->t = 0; h->rp = RP0; h->sp = SP0;
	return r;
}

int save(forth_t *h, const char *name, size_t start, size_t length)
{
	assert(h);
	if(!name)
		return -1;
	FILE *output = fopen_or_die(name, "wb");
	const int r = binary_memory_save(output, h->core, start, length);
	fclose(output);
	return r;
}

int forth(forth_t *h, FILE *in, FILE *out, const char *block)
{
	static const uw_t delta[] = { 0x0000, 0x0001, 0xFFFE, 0xFFFF };
	assert(h && in && out);
	uw_t pc = h->pc, t = h->t, rp = h->rp, sp = h->sp, *m = h->core;
	ud_t d;
	for(;;) {
		const uw_t instruction = m[pc];
		TRACE(pc, instruction, sp, rp);
		assert(!(sp & 0x8000) && !(rp & 0x8000));

		if(0x8000 & instruction) { /* literal */
			m[++sp] = t;
			t       = instruction & 0x7FFF;
			pc++;
		} else if ((0xE000 & instruction) == 0x6000) { /* ALU */
			uw_t n = m[sp], T = t;

			pc = instruction & 0x10 ? m[rp] >> 1 : pc + 1;

			switch((instruction >> 8u) & 0x1f) {
			case  0: /*T = t;*/                break;
			case  1: T = n;                    break;
			case  2: T = m[rp];                break;
			case  3: T = m[t>>1];              break;
			case  4: m[t>>1] = n; T = m[--sp]; break;
			case  5: d = (ud_t)t + (ud_t)n; T = d >> 16; m[sp] = d; n = d; break;
			case  6: d = (ud_t)t * (ud_t)n; T = d >> 16; m[sp] = d; n = d; break;
			case  7: T &= n;                   break;
			case  8: T |= n;                   break;
			case  9: T ^= n;                   break;
			case 10: T = ~t;                   break;
			case 11: T--;                      break;
			case 12: T = -(t == 0);            break;
			case 13: T = -(t == n);            break;
			case 14: T = -(n < t);             break;
			case 15: T = -((sw_t)n < (sw_t)t); break;
			case 16: T = n >> t;               break;
			case 17: T = n << t;               break;
			case 18: T = sp << 1;              break;
			case 19: T = rp << 1;              break;
			case 20: sp = t >> 1;              break;
			case 21: rp = t >> 1; T = n;       break;
			case 22: T = save(h, block, n>>1, ((ud_t)T+1)>>1); break;
			case 23: T = fputc(t, out);        break;
			case 24: T = fgetc(in);            break;
			case 25: if(t) { T=n/t; t=n%t; n=t; } else { pc=1; T=10; n=T; t=n; } break;
			case 26: if(t) { T=(sw_t)n/(sw_t)t; t=(sw_t)n%(sw_t)t; n=t; } else { pc=1; T=10; n=T; t=n; } break;
			case 27: goto finished;
			}
			sp += delta[ instruction       & 0x3];
			rp -= delta[(instruction >> 2) & 0x3];
			if(instruction & 0x20)
				T = n;
			if(instruction & 0x40)
				m[rp] = t;
			if(instruction & 0x80)
				m[sp] = t;
			t = T;
		} else if (0x4000 & instruction) { /* call */
			m[--rp] = (pc + 1) << 1;
			pc = instruction & 0x1FFF;
		} else if (0x2000 & instruction) { /* 0branch */
			pc = !t ? instruction & 0x1FFF : pc + 1;
			t = m[sp--];
		} else { /* branch */
			pc = instruction & 0x1FFF;
		}
	}
finished:
	h->pc = pc; h->sp = sp; h->rp = rp; h->t = t;
	return (int16_t)t;
}

int main(int argc, char **argv)
{
	static forth_t h;
	int interactive = 0;
	if(argc < 4)
		goto fail;
	if(!strcmp(argv[1], "i"))
		interactive = 1;
	else if(strcmp(argv[1], "f"))
		goto fail;
	load(&h, argv[2]);
	for(int i = 4; i < argc; i++) {
		FILE *in = fopen_or_die(argv[i], "rb");
		const int r = forth(&h, in, stdout, argv[3]);
		fclose(in);
		if(r != 0) {
			fprintf(stderr, "run failed: %d\n", r);
			return r;
		}
	}
	if(interactive)
		return forth(&h, stdin, stdout, argv[3]);
	return 0;
fail:
	fprintf(stderr, "usage: %s f|i input.blk output.blk file.fth\n", argv[0]);
	return -1;
}


### References

[H2 CPU]: https://github.com/howerj/forth-cpu
[J1 CPU]: http://excamera.com/sphinx/fpga-j1.html
[forth.c]: forth.c
[compiler.c]: compiler.c
[eforth.fth]: eforth.fth
[C compiler]: https://gcc.gnu.org/
[make]: https://www.gnu.org/software/make/
[Windows]: https://en.wikipedia.org/wiki/Microsoft_Windows
[Linux]: https://en.wikipedia.org/wiki/Linux
[C99]: https://en.wikipedia.org/wiki/C99
[meta.fth]: meta.fth
[DOS]: https://en.wikipedia.org/wiki/DOS
[8086]: https://en.wikipedia.org/wiki/Intel_8086
[LZSS]: https://en.wikipedia.org/wiki/Lempel%E2%80%93Ziv%E2%80%93Storer%E2%80%93Szymanski
[Run Length Encoding]: https://en.wikipedia.org/wiki/Run-length_encoding
[Huffman]: https://en.wikipedia.org/wiki/Huffman_coding
[Adaptive Huffman]: https://en.wikipedia.org/wiki/Adaptive_Huffman_coding
