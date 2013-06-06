// This patch modifies Yorick's help to allow struct definitions to pull up
// DOCUMENT statements.

func help_worker
/* xxDOCUMENT help_worker (Not for interactive use -- called by help.)
 */
{
  /* help_worker task is pushed by help function -- topic and file
     arguments are left in help_topic and help_file variables */
  topic= help_topic;   help_topic= [];
  file= help_file;     help_file= [];

  if (file) {
    mark= bookmark(file);
    line= rdline(file);

    /* looks for DOCUMENT comment before any blank lines */
    n= 10;   /* read at most 10 lines looking for DOCUMENT comment */
    while (strtok(line)(1) && n--) {
      if (strmatch(line, "/* DOCUMENT")) break;
      line= rdline(file);
    }
    if (strmatch(line, "/* DOCUMENT")) {
      do {
        if (strmatch(line, "**** Y_LAUNCH (computed at runtime) ****"))
          write, "      "+Y_LAUNCH;
        else if (strmatch(line, "**** Y_SITE (computed at runtime) ****"))
          write, "      "+Y_SITE;
        else
          write, line;
        line= rdline(file);
        if (!line) break;
      } while (!strmatch(line, "*/"));
      write, line;
    } else {
      write, "<DOCUMENT comment not found>";
    }

    mark= print(mark)(2:0);
    line= "";
    for (i=1 ; i<numberof(mark) ; i++) line+= strpart(mark(i),1:-1);
    line+= mark(i);
    write, "defined at:"+line;

  } else if (is_func(topic) == 3) {
    /* autoloaded function */
    buf = print(topic);
    n = numberof(buf);
    str = buf(1);
    escape = "\134"; /* must be octal code to not kill codger */
    newline = "\n";
    for (i=2;i<=n;++i) {
      if (strpart(str, 0:0) == escape) {
        str = strpart(str, 1:-1) + buf(i);
      } else {
        str += newline + buf(i);
      }
    }
    topic_name = file_name = string();
    if (sread(str, format="autoload of: %s from: %[^\n]",
              topic_name, file_name) == 2) {
      include, file_name, 1;
      help_topic = topic_name;
      after, 0.0, _help_auto;
    } else {
      info, topic;
    }
  } else {
    write, "<not defined in an include file, running info function>";
    info, topic;
  }
}
