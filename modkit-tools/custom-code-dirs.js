// custom-code-dirs.js
// Finds every subdirectory of `scripts/custom_code` (at any depth) which contains `.lua` files, and writes the list into
// `scripts/modkit/custom_code_dirs.lua`, which `compose.lua` uses to load them.
//
// The game can't list directories itself (`doscanpath` only scans the one directory it's given, and never returns the names it
// found), so the list has to be generated here. Re-run this after adding or removing a directory: `npm run dirs` (in `modkit-tools`).

const fs = require("fs").promises;
const path = require("path");

const custom_code_root = path.resolve(__dirname, `../scripts/custom_code`);
const target_file_path = path.resolve(__dirname, `../scripts/modkit/custom_code_dirs.lua`);

/**
 * Returns the paths (relative to `custom_code_root`, using `/`) of all directories under `dir` which directly contain a `.lua` file.
 * Hidden directories (starting with `.`) are skipped.
 *
 * @param { string } dir
 * @returns { Promise<string[]> }
 */
const findLuaDirs = async (dir) => {
	const entries = await fs.readdir(dir, { withFileTypes: true });
	const found = [];
	for (const entry of entries) {
		if (!entry.isDirectory() || entry.name.startsWith(`.`)) {
			continue;
		}
		const sub_dir = path.join(dir, entry.name);
		const sub_entries = await fs.readdir(sub_dir, { withFileTypes: true });
		if (sub_entries.some(sub_entry => sub_entry.isFile() && sub_entry.name.toLowerCase().endsWith(`.lua`))) {
			found.push(path.relative(custom_code_root, sub_dir).split(path.sep).join(`/`));
		}
		found.push(...(await findLuaDirs(sub_dir)));
	}
	return found;
};

/**
 * Sorts directories so modkit's own `lib` (and anything under it) loads first, then the rest alphabetically, which also puts each
 * directory before its subdirectories.
 *
 * @param { string[] } dirs
 * @returns { string[] }
 */
const loadOrder = (dirs) => {
	const isLib = (dir) => dir === `lib` || dir.startsWith(`lib/`);
	return [...dirs].sort((a, b) => {
		if (isLib(a) !== isLib(b)) {
			return isLib(a) ? -1 : 1;
		}
		return a.localeCompare(b);
	});
};

(async () => {
	const dirs = loadOrder(await findLuaDirs(custom_code_root));

	const target_content = (await fs.readFile(target_file_path)).toString();
	const replace_pattern = /modkit\.custom_code_dirs = {[\s\S]*?};/m;
	if (!replace_pattern.test(target_content)) {
		throw new Error(`couldn't find the 'modkit.custom_code_dirs = { ... };' table in ${target_file_path}`);
	}

	const table_lines = dirs.map(dir => `\t\t"${dir}",\n`).join(``);
	const new_content = target_content.replace(replace_pattern, `modkit.custom_code_dirs = {\n${table_lines}\t};`);
	await fs.writeFile(target_file_path, new_content);

	console.log(`[modkit] custom-code-dirs.js: ${dirs.length} custom code directories written to scripts/modkit/custom_code_dirs.lua:`);
	for (const dir of dirs) {
		console.log(`  - ${dir}`);
	}
})();
