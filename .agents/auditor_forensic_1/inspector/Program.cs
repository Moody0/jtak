using System;
using System.IO;
using System.Linq;
using System.Reflection.Metadata;
using System.Reflection.Metadata.Ecma335;
using System.Reflection.PortableExecutable;

class Program
{
    static void Main()
    {
        InspectMethod("Release", @"D:\work\jtak\jtak-backend-main\App\bin\Release\net6.0\App.dll", "RegisterOrSignInByPhoneNumber");
    }

    static void InspectMethod(string config, string path, string methodNamePattern)
    {
        Console.WriteLine($"=== Inspecting {methodNamePattern} for {config} ===");
        using var stream = File.OpenRead(path);
        using var peReader = new PEReader(stream);
        var metadataReader = peReader.GetMetadataReader();

        foreach (var handle in metadataReader.TypeDefinitions)
        {
            var typeDef = metadataReader.GetTypeDefinition(handle);
            var typeName = metadataReader.GetString(typeDef.Name);
            if (typeName.Contains(methodNamePattern))
            {
                Console.WriteLine($"Found Type: {typeName}");
                foreach (var methodHandle in typeDef.GetMethods())
                {
                    var methodDef = metadataReader.GetMethodDefinition(methodHandle);
                    var methodName = metadataReader.GetString(methodDef.Name);
                    if (methodName == "MoveNext")
                    {
                        var body = peReader.GetMethodBody(methodDef.RelativeVirtualAddress);
                        var ilBytes = body.GetILBytes();
                        Console.WriteLine($"  MoveNext IL size: {ilBytes.Length} bytes");
                    }
                }
            }
        }
    }
}
