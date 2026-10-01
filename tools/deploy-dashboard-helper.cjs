const ftp = require("basic-ftp");
const fs = require("fs");
const path = require("path");

const action = process.argv[2] || "all";
const server = process.env.FTP_SERVER;
const user = process.env.FTP_USERNAME;
const password = process.env.FTP_PASSWORD;
const rawDir = process.env.FTP_DASHBOARD_DIR || "dash.jtak.app/";
const remoteDir = rawDir.endsWith("/") ? rawDir : rawDir + "/";

async function main() {
    if (!server || !user || !password) {
        console.error("Missing FTP credentials in environment variables.");
        process.exit(1);
    }

    const client = new ftp.Client(15000);
    client.ftp.verbose = true;

    try {
        console.log(`Connecting to FTP server ${server}...`);
        await client.access({
            host: server,
            user: user,
            password: password,
            secure: false
        });

        // 1. Clean rogue items that conflict with Angular /dashboard route
        if (action === "clean" || action === "all") {
            const rogueCandidates = [
                remoteDir + "dashboard/web.config",
                remoteDir + "dashboard/index.html",
                remoteDir + "dashboard/main.js",
                remoteDir + "dashboard"
            ];

            for (const item of rogueCandidates) {
                try {
                    console.log(`Checking/removing rogue target: ${item}`);
                    if (item.endsWith("dashboard")) {
                        await client.send(`RMD ${item}`);
                        console.log(`Removed directory: ${item}`);
                    } else {
                        await client.send(`DELE ${item}`);
                        console.log(`Removed file: ${item}`);
                    }
                } catch (err) {
                    console.log(`Notice for ${item}: ${err.message}`);
                }
            }
        }

        // 2. Upload root web.config
        if (action === "sync-config" || action === "all") {
            const localWebConfig = path.join(__dirname, "..", "jtak-dashboard-main", "src", "web.config");
            const targetWebConfig = remoteDir + "web.config";

            if (fs.existsSync(localWebConfig)) {
                console.log(`Uploading ${localWebConfig} to ${targetWebConfig}...`);
                try {
                    await client.uploadFrom(localWebConfig, targetWebConfig);
                    console.log(`Uploaded web.config successfully!`);
                } catch (e) {
                    console.error(`Failed to upload web.config: ${e.message}`);
                }
            }
        }

        console.log("FTP helper task completed successfully.");
    } catch (err) {
        console.error("FTP operation failed:", err.message);
    } finally {
        client.close();
    }
}

main();
