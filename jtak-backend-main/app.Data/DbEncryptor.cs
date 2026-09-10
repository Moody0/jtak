using System;

namespace App.Data
{
    public interface IDbEncryptor
    {
        string Encrypt(string input);
        string Decrypt(string input);
    }
    public class DbEncryptor : IDbEncryptor
    {
        public string Decrypt(string input)
        {
            throw new NotImplementedException();
        }

        public string Encrypt(string input)
        {
            throw new NotImplementedException();
        }
    }
}
