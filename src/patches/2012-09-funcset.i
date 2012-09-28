// This patch works around a bug in funcdef that converts empty strings to a
// single quote mark. Here's an example of a right result then a wrong result:
//    > funcdef("write \"a\"")
//     a
//    > funcdef("write \"\"")
//     "
// The only place our code really runs into this is in funcset, where sometimes
// we need to set a variable to an empty string. It'd be hard to patch in a
// work-around for funcdef, but it's fairly easy to put a work-around in place
// for funcset. Basically, if funcset gets a single double-quote as an input
// value, it converts it to an empty string.
//
// As a side effect, it's impossible to use funcset to set a variable to a
// single double quote. However, as we commonly need to set empty strings and
// rarely/never need to set a single double-quote, this isn't much of a
// disadvantage.
//
// As of 2012-09-28, the bug in funcdef has been reported to Dave Munro.

if(is_void(yor_funcset)) yor_funcset = funcset;

func ytk_funcset(&v1,x1,&v2,x2,&v3,x3,&v4,x4,&v5,x5,&v6,x6,&v7,x7,&v8,x8) {
/* DOCUMENT funcset var1 val1 var2 val2 ...

     Equivalent to
       var1=val1; var2=val2; ...

     This function it is not useful for yorick programs.  It is intended
     to be used to create functions with funcdef that set variable values.

     Handles at most 8 var/val pairs.
     As a special case, if given an odd number of arguments, funcset
     sets the final var to [], e.g.-
       funcset var1 12.34 var2
     is equivalent to
       var1=12.34; var2=[];

   SEE ALSO: funcdef
 */
  if(x1 == "\"") x1 = "";
  if(x2 == "\"") x2 = "";
  if(x3 == "\"") x3 = "";
  if(x4 == "\"") x4 = "";
  if(x5 == "\"") x5 = "";
  if(x6 == "\"") x6 = "";
  if(x7 == "\"") x7 = "";
  yor_funcset,v1,x1,v2,x2,v3,x3,v4,x4,v5,x5,v6,x6,v7,x7,v8,x8;
}

funcset = ytk_funcset;
