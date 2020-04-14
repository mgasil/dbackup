/** 
    Creates a zip archive from the contents of a folder.
    Unwanted files can be filtered out by creating a .dbackupignore file in the source directory.
    
    Copyright: © 2020 Daniel Jansson
    License: Subject to the terms of the GPLv3 license, as written in the included LICENSE.txt file.
    Authors: mgasil
*/
module dbackup;
import std.datetime : Duration, msecs;
import std.exception : collectException;
import std.file : exists;
import std.getopt : defaultGetoptPrinter, getopt, GetoptResult;
import std.path : dirName, isValidPath;
import std.range : ElementEncodingType, isInputRange;
import std.stdio : writeln;

/**
    Creates a zip archive. Overwrites old zip archive if `output` already exists.

    Params:
        paths = All the paths to the files that are to be included in the zip archive.
        output = The path to the zip archive.
*/
public void writeZip(Range)(Range paths, string output)
    if ((isInputRange!Range) && is(ElementEncodingType!(Range) == string))
    in (output.dirName.exists /* && paths.filter!(file => !file.exists).empty */) //input ranges doesn't work well with executable preconditions.
{
    import std.algorithm : each, filter;
    import std.file :  isFile, read, write;
    import std.zip : ArchiveMember, CompressionMethod, ZipArchive;
    
    ZipArchive zip = new ZipArchive();
    
    void addZipMember(string path)
    {
        ArchiveMember file = new ArchiveMember();
        file.name = path.idup;
        auto data = cast(ubyte[]) read(path.idup);
        file.expandedData(data);
        file.compressionMethod = CompressionMethod.deflate;

        zip.addMember(file);
    }
    
    paths
   .filter!(path => path.isFile)
   .each!(path => addZipMember(path));
    write(output, zip.build);
}

unittest
{
    import std.algorithm : map;
    import std.file : dirEntries, mkdir, read, remove, rmdirRecurse, SpanMode, tempDir, write;
    import std.path : buildPath;
    import std.zip : ZipArchive;
    
    auto numberOfZipFiles(string path)
    {
        auto archive = new ZipArchive(read(path));
        return archive.directory.length;
    }
    
    auto dir = buildPath(tempDir, "dbackup");
    auto zip = buildPath(dir, "a.zip");
    dir.mkdir;
    scope(exit) dir.rmdirRecurse;
    
    write(buildPath(dir, "b"),[1]);
    write(buildPath(dir, "c"),[1]);
    write(buildPath(dir, "d"),[1]);
    
    auto files = dirEntries(dir, SpanMode.breadth)
                .map!(file => buildPath(file.name));

    writeZip(files, zip);
    assert (numberOfZipFiles(zip) == 3);
}

/**
    Checks if there is enough disk space in `dst` for folder `src` and an additional `buffer` bytes.

    Params:
        src = A path to a folder, to get its folder size.
        dst = A path to a folder, to see how much disk space is available. 
        buffer = An additional buffer to get some leeway. We don't want to end up with zero disk space.
        
   Returns: `true` if enough disk space, else `false`.
*/
public bool enoughtDiskSpace(string src, string dst, const ulong buffer = 300.mb)
    in (src.exists && dst.exists && buffer >= 0)
{
    import std.algorithm : filter, map, sum;
    import std.experimental.checkedint : checked;
    import std.file : dirEntries, getAvailableDiskSpace, isFile, SpanMode;
    import std.math : pow;
    
    auto diskSpace = getAvailableDiskSpace(dst);
    auto folderSize = dirEntries(src, SpanMode.depth)
                     .filter!(path => path.isFile)
                     .map!(file => file.size)
                     .sum;

    return diskSpace > (checked(folderSize) + buffer);
}

unittest
{
    import std.exception : collectException;
    
    assert (enoughtDiskSpace(".", "."), "Free up some disk space and run the test again!");
    assert (collectException!Error(enoughtDiskSpace(".", ".", -1)) !is null); //This is what you get when you have compatability with c!
    assert (enoughtDiskSpace(".", ".", 1.kb));
    assert (enoughtDiskSpace(".", ".", 1.mb));
    assert (enoughtDiskSpace(".", ".", 1.gb));
    assert (!enoughtDiskSpace(".", ".", 100_000.gb)); //what year will this fail?
}

/**
    Checks if `path` has existed for longer than `duration`.

    Params:
        path = A path to a file, to get its last modified time stamp.
        duration = An amount of time greater than zero. 
        
    Returns: `true` if the time difference between the current time and the time the file was last modified is greater than `duration`,
             otherwise `false`.
*/
public bool existedFor(string path, Duration duration) nothrow @safe
    in (duration >= 0.msecs)
{
    import std.datetime : abs, Clock;
    import std.exception : collectException;
    import std.file : timeLastModified;
    
    bool result;
    auto ex = collectException(
                                abs(Clock.currTime() - path.timeLastModified) >= duration, result
                              );
    
    return ex !is null ? false : result;
}

unittest
{
    import std.algorithm : map;
    import std.datetime : msecs, seconds;
    import std.exception : collectException;
    import std.file : mkdir, rmdirRecurse, tempDir, write;
    import std.path : buildPath;
  
    auto dir = buildPath(tempDir, "dbackup");
    dir.mkdir;
    scope(exit) dir.rmdirRecurse;
    
    auto path = buildPath(dir, "a");
    write(path,[1]);

    assert (existedFor(path, 0.msecs));
    assert (!existedFor(path, 10.seconds));
    assert (collectException!Error(existedFor(path, (-100).seconds)) !is null);
}

/**
    Builds a path with the current date.

    Params:
        path = A path to a file or folder.
        extension = A file extension. 
        
    Returns: `path` joined with the currrent date using the format YYYY-MM-DD, and an optional extension.
*/
public string buildPathWithCurrentDate(string path, string extension = "") @safe
    in (path.isValidPath)
    out (result; result.isValidPath)
{
    import std.array : array;
    import std.datetime : Clock, Date, SysTime;
    import std.path : asAbsolutePath, asNormalizedPath, baseName, dirName, setExtension;
    
    auto date = cast(Date) Clock.currTime();
    return setExtension( 
                         path
                        .asAbsolutePath
                        .asNormalizedPath
                        .array
                        .baseName ~ "-" ~ date.toISOExtString, extension
                       );
}

unittest
{
    import std.algorithm : endsWith;
    import std.datetime : Clock, Date, SysTime;

    string date()
    {
        auto date = cast(Date) Clock.currTime();
        return date.toISOExtString;
    }

    assert (buildPathWithCurrentDate(".").endsWith(date()));
    assert (buildPathWithCurrentDate(".", "zip").endsWith(date() ~ ".zip"));
    assert (buildPathWithCurrentDate("./..").endsWith(date()));
}

/**
    A representation of a kilobyte in binary or decimal form.
*/ 
enum KiloByte : ulong
{
    Binary = 1024,  ///
    Decimal = 1000  ///
}

/**
    Gives the number of bytes in `size` kilobytes using either a `KiloByte.Binary` or `KiloByte.Decimal` representation.

    Params:
        size = The number of kilobytes.
        bytes = The number of bytes in a kilobyte.

    Returns: The total number of bytes.

    See_Also: `mb` and `gb`.
*/
public ulong kb(ulong size, KiloByte bytes = KiloByte.Binary) nothrow pure @safe @nogc
    in (size >= 0 && size <= size.max / bytes)
{
    return size * bytes;
}

unittest
{
    import std.exception : collectException;
    
    assert (kb(0) == 0);
    assert (kb(ulong.max / KiloByte.Binary));
    assert (collectException!Error(kb(ulong.max)) !is null);
    assert (collectException!Error(kb(-1)) !is null);
    
    assert (kb(0, KiloByte.Decimal) == 0);
    assert (kb(ulong.max / KiloByte.Decimal, KiloByte.Decimal));
    assert (collectException!Error(kb(ulong.max, KiloByte.Decimal)) !is null);
    assert (collectException!Error(kb(-1, KiloByte.Decimal)) !is null);
}

/**
    A representation of a megabyte in binary or decimal form.
*/
enum MegaByte : ulong
{
    Binary = 1_048_576,   ///
    Decimal = 1_000_000   ///
}

/**
    Gives the number of bytes in `size` megabytes using either a `MegaByte.Binary` or `MegaByte.Decimal` representation.

    Params:
        size = The number of megabytes.
        bytes = The number of bytes in a megabyte.

    Returns: The total number of bytes.

    See_Also: `kb` and `gb`.
*/
public ulong mb(ulong size, MegaByte bytes = MegaByte.Binary) nothrow pure @safe @nogc
    in (size >= 0 && size <= size.max / bytes)
{
    return size * bytes;
}

unittest
{
    import std.exception : collectException;
    
    assert (mb(0) == 0);
    assert (mb(ulong.max / MegaByte.Binary));
    assert (collectException!Error(mb(ulong.max)) !is null);
    assert (collectException!Error(mb(-1)) !is null);
    
    assert (mb(0, MegaByte.Decimal) == 0);
    assert (mb(ulong.max / MegaByte.Decimal, MegaByte.Decimal));
    assert (collectException!Error(mb(ulong.max, MegaByte.Decimal)) !is null);
    assert (collectException!Error(mb(-1, MegaByte.Decimal)) !is null);
}

/**
    A representation of a gigabyte in binary or decimal form
*/ 
enum GigaByte : ulong
{
    Binary = 1_073_741_824,    ///
    Decimal = 1_000_000_000    ///
}

/**
    Gives the number of bytes in `size` gigabytes using either a `GigaByte.Binary` or `GigaByte.Decimal` representation.

    Params:
        size = The number of gigabytes.
        bytes = The number of bytes in a gigabyte.

    Returns: The total number of bytes.

    See_Also: `kb` and `mb`.
*/
public ulong gb(ulong size, GigaByte bytes = GigaByte.Binary) nothrow pure @safe @nogc
    in (size >= 0 && size <= size.max / bytes)
{
    return size * bytes;
}

unittest
{
    import std.exception : collectException;
    
    assert (gb(0) == 0);
    assert (gb(ulong.max / GigaByte.Binary));
    assert (collectException!Error(gb(ulong.max)) !is null);
    assert (collectException!Error(gb(-1)) !is null);
    
    assert (gb(0, GigaByte.Decimal) == 0);
    assert (gb(ulong.max / GigaByte.Decimal, GigaByte.Decimal));
    assert (collectException!Error(gb(ulong.max, GigaByte.Decimal)) !is null);
    assert (collectException!Error(gb(-1, GigaByte.Decimal)) !is null);
}

/*
    The different options that are accepted.
*/
private enum Option : string
{
    Verbose  = "verbose|v",
    Annotate = "annotate|a",
    Init     = "init|i",
    From     = "from|f",
    To       = "to|t"
}

/*
    Represents different commands and their associated options from the command line.
    Is designed to work together with std.getopt.getopt.
*/
private struct Command
{
    import std.algorithm : canFind, each, filter, map, sort;
    import std.array : array;
    import std.file : dirEntries, exists, isDir, isFile, read, readText, SpanMode, write;
    import std.functional : unaryFun;
    import std.path : baseName, buildNormalizedPath, dirSeparator, extension;
    import std.range : choose, dropBackOne, dropOne, ElementEncodingType, nullSink, isInputRange, split, tee;
    import std.stdio : File, writefln;
    import std.string : splitLines;
    
    private enum ErrorMessage
    {
        NoSourcePath           = "The specified source path doesn't exist",
        InvalidSourcePath      = "The specified source path is not a valid directory",
        NoDestinationPath      = "The specified destination path doesn't exist",
        InvalidDestinationPath = "The specified destination path is not a valid directory",
        FileExists             = "File %s already exists",
        NoDiskSpace            = "Not enough disk space!",
    }
    
    private enum DiagnosticMessage
    {
        NewArchive         = "Creating a new zip archive",
        AddFileToArchive   = "Adding file %s",
        OverwritingArchive = "Overwriting %s with a new zip archive",
        WritingArchive     = "Writing new zip archive to %s",
        
        NewIgnoreFile      = "Creating a new ignore file",
        AddIgnorePattern   = "Adding pattern: %s",
        WritingIgnoreFile  = "Writing new ignore file to %s",
        
        BackupStarted      = "Backup has started. This can take a long time!",
        BackupFinished     = "Backup is finished"
    }
    
    private enum Layout
    {
        Header,
        Body,
        Footer
    }
    
    private static immutable DBackupIgnoreInit = [ "/build", "/.dub", "/.git" , "*.a", "*.dll", "*.dylib", "*.exe", "*.lib" ,"*.o", "*.obj", "*.so"];
    private static immutable DBackupIgnoreFilename = ".dbackupignore";

    private string _from;   //argument to the backup command
    private bool _verbose;  //option to a command
    private bool _annotate; //ditto
    
    invariant (
                (_from == "") ||
                (_from.exists && _from.isDir)
              );
    invariant (
                (_verbose == false && _annotate == false) ||
                (_verbose == true && _annotate == false) ||
                (_verbose == true && _annotate == true)
              );
    
    /*
        Handles boolean options from std.getopt.getopt.
    */
    void flagHandler(string flag) nothrow pure @safe @nogc
        in (flag == Option.Verbose || flag == Option.Annotate)
    {
        final switch(flag)
        {
            case Option.Verbose:
                _verbose = true;
                break;
            case Option.Annotate:
                _annotate = true;
                _verbose = true;
                break;
        }
    }
    
    /*
        Handles path options from std.getopt.getopt.
        These options are arguments to commands.
    */
    void optionHandler(string option, string value)
        in (option == Option.From || option == Option.To || option == Option.Init)
    {
        import std.exception : enforce;
        
        final switch(option)
        {
            case Option.From:
                enforce(value.exists, ErrorMessage.NoSourcePath);
                enforce(value.isDir, ErrorMessage.InvalidSourcePath);
                _from = value;
                break;
            case Option.To:
                enforce(value.exists, ErrorMessage.NoDestinationPath);
                enforce(value.isDir, ErrorMessage.InvalidDestinationPath);
                backup(_from, value);
                break;
            case Option.Init:
                enforce(value.exists, ErrorMessage.NoSourcePath);
                enforce(value.isDir, ErrorMessage.InvalidSourcePath);
                init(value);
                break;
        }
    }
    
    /*
        Writes text to the console if `verbose` is `true`.
    */
    private void consoleWrite(A ...)(lazy string text, A args) @safe
    {
        if (_verbose)
            writefln(text, args);
    }
    
    /*
        The init command. It creates a default .dbackupignore file.
    */
    private void init(string from) @safe
        in(from.exists && from.isDir)
    {
        auto path = buildNormalizedPath(from, DBackupIgnoreFilename);
        if (!path.exists)
        {
            auto f = !_annotate ? File(path, "w") : File.init;
            scope(exit) f.close();
            
            consoleWriteIgnore(Layout.Header);
            
            DBackupIgnoreInit
           .tee!(line => consoleWriteIgnore(Layout.Body, line))
           .each!(line => !_annotate ? f.writeln(line) : nullSink);
           
           consoleWriteIgnore(Layout.Footer, path);
        }
        else
        {
            writefln(ErrorMessage.FileExists, path);
        }

    }
    
     /*
        Divides the diagnostic messages for the init command into a header, multiple lines representing the body and a footer.
        Does nothing if `_verbose` is `false`.
    */
    private void consoleWriteIgnore(Layout layout, string arg = "") @safe
    {
        with(Layout) final switch(layout)
        {
            case Header:
                consoleWrite(DiagnosticMessage.NewIgnoreFile);
                break;
            case Body:
                consoleWrite(DiagnosticMessage.AddIgnorePattern, arg);
                break;
            case Footer:
                consoleWrite(DiagnosticMessage.WritingIgnoreFile, arg);
                break;
        }
    }

     /*
        The backup command. It creates a new zip archive from the contents of folder `from`.
        This archive is created inside the folder `to`. If .dbackupignore exists inside the folder `from` 
        then the contents of folder `from` will be filtered with the black listed patterns found in .dbackupignore.
    */
    private void backup(string from, string to)
    {
        bool isExtension(Range)(Range extensionsData, string str) nothrow pure @safe @nogc
        if (isInputRange!Range)
        {
            return extensionsData.canFind(str.extension);
        }
        
        bool isDirname(Range)(Range dirsData, string str) @safe
        if (isInputRange!Range)
        {
            auto subDirs = str.split(dirSeparator);
            return dirsData.map!(dir => dir.dropOne)
                  .canFind!(
                               dir => choose(str.isFile, subDirs.dropBackOne, subDirs)
                                     .canFind(dir)
                           );
        }
        
        bool isFilename(Range)(Range filenames, string str) nothrow pure @safe @nogc
        if (isInputRange!Range)
        {
            return filenames.canFind(str.baseName);
        }
        
        if (!enoughtDiskSpace(from, to))
        {
            writeln(ErrorMessage.NoDiskSpace);
            return;
        }
        
        consoleWrite(DiagnosticMessage.BackupStarted);
        auto ignore = buildNormalizedPath(from, DBackupIgnoreFilename);
        if (ignore.exists)
        {
            immutable ignores = ignore.readText.splitLines();
            auto extensions = ignores.filter!(word => word[0] == '*').map!(word => word[1 .. $]);
            auto dirs = ignores.filter!(word => word[0] == '/');
            auto filenames = ignores.filter!(word => word[0] != '*'&&  word[0] != '/');
            
            writeZip!(path => !(isDirname(dirs, path) ||
                                isExtension(extensions, path) ||
                                isFilename(filenames, path)))
                     (from, to);
        }
        else
        {
            writeZip!(path => true)(from, to);
        }
        
        consoleWrite(DiagnosticMessage.BackupFinished);
    }
    
    /*
        Filters the content inside `from` with `predicate` and then writes them to a zip archive inside `to`.
    */
    private void writeZip(alias predicate)(string from, string to)
        if (is(typeof(unaryFun!predicate)))
    {
        consoleWriteZip(Layout.Header);
        auto path = buildNormalizedPath(from, buildPathWithCurrentDate(from, "zip"));
        auto exists = path.exists;
        
        auto range = dirEntries(from, SpanMode.breadth)
                    .map!(f => buildNormalizedPath(f.name))
                    .filter!(x => predicate(x) && x != path)
                    .array
                    .sort
                    .tee!(x => consoleWriteZip(Layout.Body, x));
        
        !_annotate ? range.writeZip(path) : range.each;
        consoleWriteZip(Layout.Footer, path, exists);
    }
    
     /*
        Divides the diagnostic messages for the backup command into a header, multiple lines representing the body and a footer.
        Does nothing if `_verbose` is `false`.
    */
    private void consoleWriteZip(Layout layout, string file = "", bool flag = false) @safe
    {
        with(Layout) final switch(layout)
        {
            case Header:
                consoleWrite(DiagnosticMessage.NewArchive);
                break;
            case Body:
                consoleWrite(DiagnosticMessage.AddFileToArchive, file);
                break;
            case Footer:
                flag
                ?
                    consoleWrite(DiagnosticMessage.OverwritingArchive, file)
                :
                    consoleWrite(DiagnosticMessage.WritingArchive, file);
                break;
        }
    }
    
}

/*
    Defines the options and executes associated command(s). Supported commands are `init` and `backup`.
    Returns a `GetoptResult` that can be checked for additional information. Will throw an exception if something goes wrong.
*/
private GetoptResult runCommands(string[] args)
{  
    Command command;
    return getopt(args,
    cast(string) Option.Verbose, "Explain what is being done.", &command.flagHandler,
    cast(string) Option.Annotate, "Do not perform any action, and explain what would have been done", &command.flagHandler,
    cast(string) Option.Init, "Create a default .dbackupignore file.", &command.optionHandler,
    cast(string) Option.From, "Source path to an existing directory.", &command.optionHandler,
    cast(string) Option.To, "Destination path to an existing directory.", &command.optionHandler);
}

unittest
{
    import std.file : mkdir, rmdirRecurse, tempDir, write;
    import std.path : buildPath;
    
    immutable DBackup = "dbackup";
    immutable DBackupIgnore = ".dbackupignore";
       
    auto dir = buildPath(tempDir, DBackup);
    dir.mkdir;
    scope(exit) dir.rmdirRecurse;
    
    runCommands([DBackup, "--from=" ~ dir, "--to=" ~ dir]); //empty
    assert (!buildPath(dir, DBackup ~ ".zip").exists);
         
    runCommands([DBackup, "--init=" ~ dir, "-a"]);
    assert (!buildPath(dir, DBackupIgnore).exists);
    
    runCommands([DBackup, "--init=" ~ dir, "-a"]);
    assert (!buildPath(dir, DBackupIgnore, "-a", "-v").exists);
    
    runCommands([DBackup, "--init=" ~ dir]);
    assert (buildPath(dir, DBackupIgnore).exists);
    
    runCommands([DBackup, "--init=" ~ dir, "-v"]);
    assert (buildPath(dir, DBackupIgnore).exists);
    
    write(buildPath(dir, "a"),[1]);
    write(buildPath(dir, "b"),[1]);
    write(buildPath(dir, "c"),[1]); 
    
    runCommands([DBackup, "--from=" ~ dir, "--to=" ~ dir, "-a"]);
    assert (!buildPath(dir, DBackup ~ ".zip").exists);
    
    runCommands([DBackup, "--from=" ~ dir, "--to=" ~ dir, "-v", "-a"]);
    assert (!buildPath(dir, DBackup ~ ".zip").exists);
    
    runCommands([DBackup, "--to=" ~ dir, "--from=" ~ dir]);
    assert (buildPath(dir, buildPathWithCurrentDate(DBackup, "zip")).exists);
    
    runCommands([DBackup, "--from=" ~ dir, "--to=" ~ dir, "-v"]);
    assert (buildPath(dir, buildPathWithCurrentDate(DBackup, "zip")).exists);
    
    runCommands([DBackup, "--from=" ~ dir, "--to=" ~ dir, "-v", "--init=" ~ dir]);
    assert (buildPath(dir, DBackupIgnore).exists);
    assert (buildPath(dir, buildPathWithCurrentDate(DBackup, "zip")).exists);
}

void main(string[] args)
{
    immutable HelpMessage = "Creates a zip archive from a folder. Unwanted files can be filtered out by creating a .dbackupignore file in the source directory.";
    GetoptResult result;
    auto ex = collectException(runCommands(args), result);

    if (ex !is null)
    {
        writeln(ex.msg);
    }
    else if (result.helpWanted)
    {
        defaultGetoptPrinter(HelpMessage, result.options);
    }
}

