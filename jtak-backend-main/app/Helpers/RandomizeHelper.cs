using System;
using System.Collections.Generic;
using System.Linq;

namespace App.Helpers
{
    public static class RandomizeHelper
    {
        private static readonly Random rnd = new Random();
        private static readonly List<string> Fnlst = new List<string>() { "خالد", "أحمد", "سمير", "سعيد", "أيمن", "تحسين", "نور", "طارق", "محمد", "أحمد", "مضر", "محمود", "زين", "أنس", "ابراهيم", "عبد الله", "عبد الرحمن", "عبد القادر", "عبد السميع" };
        private static readonly List<string> Lnlst = new List<string>() { "العكاري", "الخباز", "الطحان", "خانكان", "السباعي", "الأتاسي", "الرفاعي", "بكور", "القرشي", "عبد الصمد", "حسون", "العسة", "الحبال", "حلاق", "درويش", "عبد الله", "الآغا", "حاكمي", "الصالح" };
        //private static readonly List<string> Fnlst = new List<string>(){ "Smith", "Johnson", "Williams", "Jones", "Brown", "Davis", "Miller", "Wilson", "Moore", "Taylor", "Anderson", "Thomas", "Jackson", "White", "Harris", "Martin", "Thompson", "Garcia", "Martinez", "Robinson", "Clark", "Rodriguez", "Lewis", "Lee", "Walker", "Hall", "Allen", "Young", "Hernandez", "King", "Wright", "Lopez", "Hill", "Scott", "Green", "Adams", "Baker", "Gonzalez", "Nelson", "Carter", "Mitchell", "Perez", "Roberts", "Turner", "Phillips", "Campbell", "Parker", "Evans", "Edwards", "Collins", "Stewart", "Sanchez", "Morris", "Rogers", "Reed", "Cook", "Morgan", "Bell", "Murphy", "Bailey", "Rivera", "Cooper", "Richardson", "Cox", "Howard", "Ward", "Torres", "Peterson", "Gray", "Ramirez", "James", "Watson", "Brooks", "Kelly", "Sanders", "Price", "Bennett", "Wood", "Barnes", "Ross", "Henderson", "Coleman", "Jenkins", "Perry", "Powell", "Long", "Patterson", "Hughes", "Flores", "Washington", "Butler", "Simmons", "Foster", "Gonzales", "Bryant", "Alexander", "Russell", "Griffin", "Diaz", "Hayes" };
        //private static readonly List<string> Lnlst = new List<string>() { "Aiden", "Jackson", "Mason", "Liam", "Jacob", "Jayden", "Ethan", "Noah", "Lucas", "Logan", "Caleb", "Caden", "Jack", "Ryan", "Connor", "Michael", "Elijah", "Brayden", "Benjamin", "Nicholas", "Alexander", "William", "Matthew", "James", "Landon", "Nathan", "Dylan", "Evan", "Luke", "Andrew", "Gabriel", "Gavin", "Joshua", "Owen", "Daniel", "Carter", "Tyler", "Cameron", "Christian", "Wyatt", "Henry", "Eli", "Joseph", "Max", "Isaac", "Samuel", "Anthony", "Grayson", "Zachary", "David", "Christopher", "John", "Isaiah", "Levi", "Jonathan", "Oliver", "Chase", "Cooper", "Tristan", "Colton", "Austin", "Colin", "Charlie", "Dominic", "Parker", "Hunter", "Thomas", "Alex", "Ian", "Jordan", "Cole", "Julian", "Aaron", "Carson", "Miles", "Blake", "Brody", "Adam", "Sebastian", "Adrian", "Nolan", "Sean", "Riley", "Bentley", "Xavier", "Hayden", "Jeremiah", "Jason", "Jake", "Asher", "Micah", "Jace", "Brandon", "Josiah", "Hudson", "Nathaniel", "Bryson", "Ryder", "Justin", "Bryce",/*female*/"Sophia", "Emma", "Isabella", "Olivia", "Ava", "Lily", "Chloe", "Madison", "Emily", "Abigail", "Addison", "Mia", "Madelyn", "Ella", "Hailey", "Kaylee", "Avery", "Kaitlyn", "Riley", "Aubrey", "Brooklyn", "Peyton", "Layla", "Hannah", "Charlotte", "Bella", "Natalie", "Sarah", "Grace", "Amelia", "Kylie", "Arianna", "Anna", "Elizabeth", "Sophie", "Claire", "Lila", "Aaliyah", "Gabriella", "Elise", "Lillian", "Samantha", "Makayla", "Audrey", "Alyssa", "Ellie", "Alexis", "Isabelle", "Savannah", "Evelyn", "Leah", "Keira", "Allison", "Maya", "Lucy", "Sydney", "Taylor", "Molly", "Lauren", "Harper", "Scarlett", "Brianna", "Victoria", "Liliana", "Aria", "Kayla", "Annabelle", "Gianna", "Kennedy", "Stella", "Reagan", "Julia", "Bailey", "Alexandra", "Jordyn", "Nora", "Carolin", "Mackenzie", "Jasmine", "Jocelyn", "Kendall", "Morgan", "Nevaeh", "Maria", "Eva", "Juliana", "Abby", "Alexa", "Summer", "Brooke", "Penelope", "Violet", "Kate", "Hadley", "Ashlyn", "Sadie", "Paige", "Katherine", "Sienna", "Piper" };
        public static int Next(int? maxValue = null, int? minValue = null)
        {
            return maxValue.HasValue && minValue.HasValue ? rnd.Next(maxValue.Value, minValue.Value) :
                    maxValue.HasValue ? rnd.Next(maxValue.Value) :
                    minValue.HasValue ? rnd.Next(minValue.Value) : rnd.Next();
        }

        public static string RandomLastName()
        {
            
            return Lnlst.ElementAt(rnd.Next(Lnlst.Count));
        }
        public static string RandomFirstName()
        {
            
            return Fnlst.ElementAt(rnd.Next(Fnlst.Count));
        }
        public static string RandomFullName()
        {
            return RandomFirstName() + " " + RandomLastName();
        }
        public static string RandomUserName()
        {
            return RandomFirstName() + "_" + RandomLastName();
        }
        public static string RandomHexHash(int length = 16)
        {
            //length = length > 32 ? 32 : length;
            var bytes = new byte[(int)Math.Ceiling(length / 2.0)];
            rnd.NextBytes(bytes);
            //using (var rng = new RNGCryptoServiceProvider()) rng.GetBytes(bytes);
            return BitConverter.ToString(bytes).Replace("-", "").ToLower().Substring(0, length);
        }
        public static string RandomEmail()
        {
            var emailProviders = new List<string> { "@hotmail.com", "@yahoo.com", "@nbs-us.net", "@live" };
            return RandomFirstName() + "." + RandomLastName() + emailProviders[rnd.Next(0, 3)];
        }
        public static string RandomSentence()
        {
            string[] article = { "the", "a", "one", "some", "any", };
            string[] noun = { "boy", "girl", "dog", "town", "car", };
            string[] verb = { "drove", "jumped", "ran", "walked", "skipped", };
            string[] preposition = { "to", "from", "over", "under", "on", };

            int randomarticle = rnd.Next(article.Length);
            int randomnoun = rnd.Next(noun.Length);
            int randomverb = rnd.Next(verb.Length);
            int randompreposition = rnd.Next(preposition.Length);
            int randomarticle2 = rnd.Next(article.Length);
            int randomnoun2 = rnd.Next(noun.Length);

            return
                $"{article[randomarticle]} {noun[randomnoun]} {verb[randomverb]} {preposition[randompreposition]} {article[randomarticle2]} {noun[randomnoun]}";
        }

    }
}
