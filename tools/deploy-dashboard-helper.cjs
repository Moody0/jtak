const ftp = require("basic-ftp");
const fs = require("fs");
const path = require("path");

const action = process.argv[2] || "all"; // 'clean', 'sync-config', or 'all'
const server = process.env.FTP_SERVER;
const user = process.env.FTP_USERNAME;
const password = process.env.FTP_PASSWORD;
const rawDir = process.env.FTP_DASHBOARD_DIR || "dash.jtak.app/";
const remoteDir = rawDir.endsWith("/") ? rawDir : rawDir + "/";

async function main() {
    if (!server || !user || !password) {
        console.error("Missing FTP credentials in environment variables (FTP_SERVER, FTP_USERNAME, FTP_PASSWORD).");
        process.exit(1);
    }

    const client = new ftp.Client(30000);
    client.ftp.verbose = true;

    try {
        console.log(`Connecting to FTP server ${server}...`);
        await client.access({
            host: server,
            user: user,
            password: password,
            secure: false
        });

        console.log(`Successfully connected. Inspecting remote directory: ${remoteDir}`);
        const list = await client.list(remoteDir);
        console.log(`Found ${list.length} items in ${remoteDir}:`);
        for (const item of list) {
            const kind = item.isDirectory ? "DIR" : "FILE";
            console.log(` - [${kind}] ${item.name} (${item.size} bytes)`);
        }

        // Action: clean rogue dashboard directory
        if (action === "clean" || action === "all") {
            const rogueDashboard = list.find(item => item.name.toLowerCase() === "dashboard");
            if (rogueDashboard) {
                const roguePath = remoteDir + rogueDashboard.name;
                console.log(`⚠️ Detected rogue '${rogueDashboard.name}' item at ${roguePath}`);

                if (rogueDashboard.isDirectory) {
                    try {
                        console.log(`Listing contents of ${roguePath}...`);
                        const subItems = await client.list(roguePath + "/");
                        for (const sub of subItems) {
                            console.log(`   * [${sub.isDirectory ? 'DIR' : 'FILE'}] ${sub.name} (${sub.size} bytes)`);
                        }
                    } catch (e) {
                        console.log(`Could not inspect subitems: ${e.message}`);
                    }

                    console.log(`Removing directory recursively: ${roguePath}`);
                    try {
                        await client.removeDir(roguePath);
                        console.log(`✅ Successfully removed rogue directory: ${roguePath}`);
                    } catch (e) {
                        console.error(`❌ Failed to removeDir ${roguePath}: ${e.message}`);
                    }
                } else {
                    console.log(`Removing file: ${roguePath}`);
                    try {
                        await client.remove(roguePath);
                        console.log(`✅ Successfully removed rogue file: ${roguePath}`);
                    } catch (e) {
                        console.error(`❌ Failed to remove file ${roguePath}: ${e.message}`);
                    }
                }
            } else {
                console.log(`No rogue 'dashboard' folder found at root of ${remoteDir}.`);
            }
        }

        // Action: sync root web.config
        if (action === "sync-config" || action === "all") {
            const localWebConfig = path.join(__dirname, "..", "jtak-dashboard-main", "src", "web.config");
            const targetWebConfig = remoteDir + "web.config";

            if (fs.existsSync(localWebConfig)) {
                console.log(`Uploading production web.config from ${localWebConfig} to ${targetWebConfig}...`);
                try {
                    await client.uploadFrom(localWebConfig, targetWebConfig);
                    console.log(`✅ Successfully uploaded ${targetWebConfig}`);
                } catch (e) {
                    console.error(`❌ Failed to upload web.config: ${e.message}`);
                    // If file is locked, try small delay and retry
                    console.log("Retrying upload in 3s...");
                    await new Promise(r => setTimeout(r, 3000));
                    await client.uploadFrom(localWebConfig, targetWebConfig);
                    console.log(`✅ Successfully uploaded ${targetWebConfig} on retry`);
                }
            } else {
                console.warn(`Local web.config not found at ${localWebConfig}`);
            }
        }

        console.log("FTP helper task completed successfully.");
    } catch (err) {
        console.error("FTP operation failed:", err.message);
        process.exit(1);
    } finally {
        client.close();
    }
}

main();
