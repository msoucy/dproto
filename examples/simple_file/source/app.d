import std.stdio;
import dproto.dproto;

mixin ProtocolBuffer!"person.proto";
 

int main()
{
    Person person;
    person.name = "John Doe";
    person.id = 1234;
    person.email = "jdoe@example.com";
    
    ubyte[] serializedObject = person.serialize();

    Person person2 = Person(serializedObject);
    writeln("Name: ", person2.name);
    writeln("E-mail: ", person2.email);
    return 0;
}
