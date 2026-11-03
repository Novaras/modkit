// test.js
// Runs modkit's offline unit tests (`tests/lua/**/*.test.lua`) with a Lua 4.0 interpreter (the game's dialect).
//
// Usage: `npm test`, or `npm test -- table_util` to only run test files whose name contains "table_util".
// The interpreter is taken from the `LUA4` env var, else `lua4` on the PATH. It must be Lua 4.0, not 4.0.1
// (4.0.1 fixed parser bugs the game still has), built from https://www.lua.org/ftp/lua-4.0.tar.gz.

const path = require("path");
const { spawnSync } = require("child_process");
const globby = require("globby");

const repo_root = path.resolve(__dirname, "..");

/**
 * Returns the Lua 4.0 interpreter to use, or `null` if none is available.
 *
 * @returns { string | null }
 */
const findLua = () => {
	const candidates = [process.env.LUA4, `lua4`].filter((candidate) => candidate);
	for (const candidate of candidates) {
		const probe = spawnSync(candidate, [`-v`], { encoding: `utf8` });
		if (!probe.error) {
			return candidate;
		}
	}
	return null;
};

(async () => {
	const lua = findLua();
	if (!lua) {
		console.error(`[modkit] test.js: no Lua 4.0 interpreter found.`);
		console.error(`\tBuild Lua 4.0 (not 4.0.1) from https://www.lua.org/ftp/lua-4.0.tar.gz, then set LUA4 to its bin/lua,`);
		console.error(`\ti.e: LUA4=~/lua-4.0/bin/lua npm test`);
		process.exit(1);
	}

	const only = process.argv[2];
	const files = (await globby(`tests/lua/**/*.test.lua`, { cwd: __dirname }))
		.filter((file) => !only || path.basename(file).includes(only))
		.sort();

	if (files.length === 0) {
		console.error(`[modkit] test.js: no test files found${only ? ` matching '${only}'` : ``}.`);
		process.exit(1);
	}

	const failed = [];
	for (const file of files) {
		console.log(`\n== ${file} ==`);
		// run from the repo root, so test files can load modkit with repo-relative paths
		const result = spawnSync(lua, [path.join(`modkit-tools`, file)], { cwd: repo_root, stdio: `inherit` });
		if (result.status !== 0) {
			failed.push(file);
		}
	}

	console.log(`\n${files.length - failed.length} of ${files.length} test file(s) passed.`);
	if (failed.length > 0) {
		console.log(`Failed: ${failed.join(`, `)}`);
		process.exit(1);
	}
})();
