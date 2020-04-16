DBackup Coding Style
====================

Tabs and indentation
--------------------

`No Tab` characters should be used in source code.
Use `4 spaces` instead of tabs.

Indent `pre` and `post` contracts written in expression form, and `template constraints`.

```D
void Foo(Range)(Range range)
    if (isInputRange!Range && is(ElementEncodingType!(Range) == string))
    in (range.isValidPath)
    out (result; result.isValidPath)
{
}
```

Indent statements belonging to a `case` inside a `switch` statement.

```D
final switch(someEnum)
{
    case Element.Air:
        // statements
        break;
    case Element.Fire:
        // statements
        break;
}
```

Identifiers
-----------

Class, enum, struct and union names: `PascalCase`, e.g. `SomeClass`.  
Module and package names: `lowercase`, e.g `module std.range`.  
Method and property names: `camelCase`, e.g. `doSomething`.  
Private and protected class and struct fields: `camelCase` prepended with an underscore, e.g. `_field`.  
Public struct fields (POD): `camelCase`, e.g. `data`.   
Enum member names: `PascalCase`, e.g. 
```D
enum Element
{
    Air, Fire
}
```

Spaces
------

Always put space after a delimiter like `,` or `;`.
```D
function(x, y, z);

foreach (el; range)

auto list = [1, 2, 3, 4, 5];
```
Use spaces between assignments, binary operators, `cast` and lambdas.
```D
a + b

a / b

a == b

a && b

arr[0 .. 1]

int a = 0;

b += 1;

ubyte b = cast(byte) a;

filter!(a => a == 0);
```

Put a space after `assert`, `if`, `for`, `foreach`, and `while`.  
Put also a space after pre and post contracts written in expression form.
```D
assert (isValid());

if (pred == true)

for (auto i = 0; i < length; i++)

foreach (el; range)

while (isNotFinished())

do
{
    // statement
} while (isNotFinished())

in (range.isValid())
out (result; result == true)
```
Selective imports should have a space before and after the colon `:` like `import std.stdio : writeln`

Brackets
--------

Curly brackets uses `Allman style`:
```D
if (a == b)
{
    //
}

```
Square brackets uses `Allman style` if the statement doesn't fit in one line.

```D
immutable a = [1, 2, 3];

immutable b = 
[
    "veryLongStringA",
    "veryLongStringB",
    "veryLongStringC",
];

```
