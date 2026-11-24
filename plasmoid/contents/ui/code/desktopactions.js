.pragma library

// Lists and launches an app's [Desktop Action] entries through the shell

const SEP = "\x1f";

// Prints "id SEP name SEP icon SEP exec" per action, in Actions= order
const AWK = `
/^\\[/ {
    sec = $0; act = ""
    if (sec ~ /^\\[Desktop Action .*\\]$/) act = substr(sec, 17, length(sec) - 17)
    next
}
{ k = $0; sub(/[ \\t]*=.*/, "", k); v = $0; sub(/^[^=]*=[ \\t]*/, "", v) }
sec == "[Desktop Entry]" && k == "Actions" { order = v }
act != "" && k == "Name" { name[act] = v }
act != "" && k == "Name[" lang "]" { lname[act] = v }
act != "" && k == "Name[" short "]" { sname[act] = v }
act != "" && k == "Icon" { icon[act] = v }
act != "" && k == "Exec" { ex[act] = v }
END {
    n = split(order, ids, ";")
    for (i = 1; i <= n; i++) {
        a = ids[i]
        if (a == "" || ex[a] == "") continue
        nm = lname[a] != "" ? lname[a] : (sname[a] != "" ? sname[a] : name[a])
        printf "%s\\037%s\\037%s\\037%s\\n", a, nm, icon[a], ex[a]
    }
}`;

function shellQuote(s) {
    return "'" + String(s).replace(/'/g, "'\\''") + "'";
}

function stripFile(url) {
    let s = String(url);
    if (s.startsWith("file://")) {
        try {
            s = decodeURIComponent(s.slice(7));
        } catch (e) {
            s = s.slice(7);
        }
    }
    return s;
}

// Candidate .desktop paths for a launcher URL (applications:x.desktop or file://)
function candidatePaths(launcherUrl, appDirs) {
    const url = String(launcherUrl || "").split("?")[0];
    if (url.startsWith("applications:")) {
        let id = url.slice("applications:".length);
        if (!id)
            return [];
        if (!id.endsWith(".desktop"))
            id += ".desktop";
        return appDirs.map(dir => stripFile(dir).replace(/\/+$/, "") + "/" + id);
    }
    const path = stripFile(url);
    return path.startsWith("/") && path.endsWith(".desktop") ? [path] : [];
}

// Shell command listing the actions of the first existing candidate, or "" if none
function listCommand(launcherUrl, appDirs, localeName) {
    const paths = candidatePaths(launcherUrl, appDirs);
    if (paths.length === 0)
        return "";
    const lang = String(localeName || "");
    const short = lang.split("_")[0];
    return "for f in " + paths.map(shellQuote).join(" ")
        + "; do [ -f \"$f\" ] && exec awk -v lang=" + shellQuote(lang)
        + " -v short=" + shellQuote(short) + " " + shellQuote(AWK) + " \"$f\"; done";
}

function parse(stdout) {
    return String(stdout || "").split("\n").filter(line => line.length > 0).map(line => {
        const parts = line.split(SEP);
        return { id: parts[0], name: parts[1] || parts[0], icon: parts[2] || "", exec: parts[3] || "" };
    }).filter(action => action.exec.length > 0);
}

// Detached shell command running an Exec line without its field codes
function launchCommand(exec) {
    const line = String(exec).replace(/%[fFuUdDnNickvm]/g, "").replace(/%%/g, "%").trim();
    return "setsid -f sh -c " + shellQuote(line) + " >/dev/null 2>&1";
}
