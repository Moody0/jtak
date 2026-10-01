const ftp = require("basic-ftp");
const fs = require("fs");
const path = require("path");

const mode = process.argv[2]; // 'offline' or 'online'
const server = process.env.FTP_SERVER;
const user = process.env.FTP_USERNAME;
const password = process.env.FTP_PASSWORD;
const remoteDir = process.env.FTP_BACKEND_DIR || "api.jtak.app/";

async function main() {
    if (!server || !user || !password) {
        console.error("Missing FTP credentials in environment variables.");
        process.exit(1);
    }

    const client = new ftp.Client(30000);
    client.ftp.verbose = true;

    try {
        await client.access({
            host: server,
            user: user,
            password: password,
            secure: false
        });

        const targetDir = remoteDir.endsWith("/") ? remoteDir : remoteDir + "/";
        const offlinePath = targetDir + "app_offline.htm";

        if (mode === "offline") {
            console.log(`[Offline Mode] Uploading ${offlinePath}...`);
            const offlineContent = `<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><title>JTAK System Update</title></head>
<body style="font-family:sans-serif;text-align:center;padding:50px;">
  <h2>Updating JTAK Backend...</h2>
  <p>The system is updating. Please wait a few seconds.</p>
</body>
</html>`;
            const tmpFile = path.join(__dirname, "temp_app_offline.htm");
            fs.writeFileSync(tmpFile, offlineContent, "utf8");
            await client.uploadFrom(tmpFile, offlinePath);
            try { fs.unlinkSync(tmpFile); } catch(e){}
            console.log("Uploaded app_offline.htm successfully. Waiting 5s for IIS to release file locks...");
            await new Promise(r => setTimeout(r, 5000));
        } else if (mode === "online") {
            console.log(`[Online Mode] Removing ${offlinePath}...`);
            try {
                await client.remove(offlinePath);
                console.log("Removed app_offline.htm successfully. IIS is now reloading with updated assemblies.");
            } catch (err) {
                console.log("Notice: app_offline.htm removed or absent:", err.message);
            }
        }
    } catch (err) {
        console.error("FTP operation failed:", err.message);
        if (mode === "offline") process.exit(1);
    } finally {
        client.close();
    }
}

main();
