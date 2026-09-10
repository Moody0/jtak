//using System.Collections.Generic;
//using System.IO;
//using System.Linq;
//using ICSharpCode.SharpZipLib.Core;
//using ICSharpCode.SharpZipLib.Zip;

//namespace App.Shared.Services.Helpers
//{
//    public static class ZipUtil
//    {
//        public static void ZipFiles(string inputFolderPath, string outputPathAndFile, string password)
//        {
//            var list = GenerateFileList(inputFolderPath); // generate file list
//            var trimLength = (Directory.GetParent(inputFolderPath)).ToString().Length;
//            // find number of chars to remove     // from orginal file path
//            trimLength += 1; //remove '\'
//            var outPath = inputFolderPath + @"\" + outputPathAndFile;
//            var oZipStream = new ZipOutputStream(File.Create(outPath)); // create zip stream
//            if (!string.IsNullOrEmpty(password)) oZipStream.Password = password;
//            oZipStream.SetLevel(9); // maximum compression
//            foreach (var item in list) // for each file, generate a zipentry
//            {
//                var oZipEntry = new ZipEntry(item.Remove(0, trimLength));
//                oZipStream.PutNextEntry(oZipEntry);

//                if (!item.EndsWith(@"/")) // if a file ends with '/' its a directory
//                {
//                    var ostream = File.OpenRead(item);
//                    var obuffer = new byte[ostream.Length];
//                    ostream.Read(obuffer, 0, obuffer.Length);
//                    oZipStream.Write(obuffer, 0, obuffer.Length);
//                }
//            }
//            oZipStream.Finish();
//            oZipStream.Close();
//        }


//        private static List<string> GenerateFileList(string Dir)
//        {
//            var fils = new List<string>();
//            var empty = true;
//            foreach (var file in Directory.GetFiles(Dir)) // add each file in directory
//            {
//                fils.Add(file);
//                empty = false;
//            }

//            if (empty)
//            {
//                // if directory is completely empty, add it
//                if (Directory.GetDirectories(Dir).Length == 0)
//                {
//                    fils.Add(Dir + @"/");
//                }
//            }

//            fils.AddRange(Directory.GetDirectories(Dir).SelectMany(GenerateFileList));
//            return fils; // return file list
//        }


//        public static void UnZipFiles(string zipPathAndFile, string outputFolder, bool deleteZipFile = false, string password = null)
//        {
//            if (Directory.Exists(outputFolder)) Directory.Delete(outputFolder, true);
//            Directory.CreateDirectory(outputFolder);
//            var s = new ZipInputStream(File.OpenRead(zipPathAndFile));
//            if (!string.IsNullOrEmpty(password)) s.Password = password;
//            ZipEntry theEntry;
//            var tmpEntry = string.Empty;
//            while ((theEntry = s.GetNextEntry()) != null)
//            {
//                var directoryName = outputFolder;
//                var fileName = Path.GetFileName(theEntry.Name);
//                // create directory 
//                if (directoryName != "")
//                {
//                    Directory.CreateDirectory(directoryName);
//                }
//                if (fileName != string.Empty)
//                {
//                    if (theEntry.Name.IndexOf(".ini") < 0)
//                    {
//                        var fullPath = directoryName + "\\" + theEntry.Name;
//                        fullPath = fullPath.Replace("\\ ", "\\");
//                        var fullDirPath = Path.GetDirectoryName(fullPath);
//                        if (!Directory.Exists(fullDirPath)) Directory.CreateDirectory(fullDirPath);
//                        var streamWriter = File.Create(fullPath);
//                        var data = new byte[2048];
//                        while (true)
//                        {
//                            var size = s.Read(data, 0, data.Length);
//                            if (size > 0)
//                            {
//                                streamWriter.Write(data, 0, size);
//                            }
//                            else
//                            {
//                                break;
//                            }
//                        }
//                        streamWriter.Close();
//                    }
//                }
//            }
//            s.Close();
//            if (deleteZipFile)
//                File.Delete(zipPathAndFile);
//        }


//        public static void ExtractZipFile(string archiveFilenameIn, string outFolder, string password = null)
//        {
//            ZipFile zf = null;
//            try
//            {
//                var fs = File.OpenRead(archiveFilenameIn);
//                zf = new ZipFile(fs);
//                if (!string.IsNullOrEmpty(password))
//                {
//                    zf.Password = password;		// AES encrypted entries are handled automatically
//                }
//                foreach (ZipEntry zipEntry in zf)
//                {
//                    if (!zipEntry.IsFile)
//                    {
//                        continue;			// Ignore directories
//                    }
//                    var entryFileName = zipEntry.Name;
//                    // to remove the folder from the entry:- entryFileName = Path.GetFileName(entryFileName);
//                    // Optionally match entrynames against a selection list here to skip as desired.
//                    // The unpacked length is available in the zipEntry.Size property.

//                    var buffer = new byte[4096];		// 4K is optimum
//                    var zipStream = zf.GetInputStream(zipEntry);

//                    // Manipulate the output filename here as desired.
//                    var fullZipToPath = Path.Combine(outFolder, entryFileName);
//                    var directoryName = Path.GetDirectoryName(fullZipToPath);
//                    if (directoryName.Length > 0)
//                        Directory.CreateDirectory(directoryName);

//                    // Unzip file in buffered chunks. This is just as fast as unpacking to a buffer the full size
//                    // of the file, but does not waste memory.
//                    // The "using" will close the stream even if an exception occurs.
//                    using (var streamWriter = File.Create(fullZipToPath))
//                    {
//                        StreamUtils.Copy(zipStream, streamWriter, buffer);
//                    }
//                }
//            }
//            finally
//            {
//                if (zf != null)
//                {
//                    zf.IsStreamOwner = true; // Makes close also shut the underlying stream
//                    zf.Close(); // Ensure we release resources
//                }
//            }
//        }
//    }
//}
