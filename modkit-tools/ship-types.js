const fs = require("fs").promises;
const path = require("path");
const globby = require("globby");

/**
 * Converts an object or Array into a string which is the Lua representation of that object or Array.
 *
 * @param { Object | Array } obj
 * @param { number } indent 
 * @returns string
 */
const objToLuaTable = (obj, indent = 0) => {
	const resolveValue = (v) => {
		switch (typeof v) {
			case 'object':
				return objToLuaTable(v, indent + 1);
			case `string`:
				return `'${v}'`;
			case `function`:
				return v.toString();
			default:
				return v;
		}
	};

	const key_vals = (() => {
		if (obj instanceof Array) {
			return obj.reduce((acc, v, i) => {
				const resolved = resolveValue(v);
				return `${acc}${'\t'.repeat(indent + 1)}[${i}] = ${resolved},\n`;
			}, ``);
		} else {
			return Object.entries(obj).reduce((acc, [k, v]) => {
				const resolved = resolveValue(v);
				return `${acc}${'\t'.repeat(indent + 1)}'${k}' = ${resolved},\n`;
			}, ``);
		}
	})();

	return `{\n${key_vals}${'\t'.repeat(indent)}}`;
};

/**
 * This script looks for all `.ship` files, and uses their names to generate a list of ship types.
 * 
 * This list is then converted to a Lua table (as a string), and inserted into `ship-types.lua`.
 */
(async () => {
	const dir = `${__dirname}/../ship/**/*.ship`.replaceAll(/\\/g, '/');
	// paths to all the .ship files
	const paths = await globby([dir]);

	const ship_types = [];
	for (const path of paths) {
		// console.log(path);
		const ship_type = path.split(`/`).slice(-1)[0].split('.')[0];
		ship_types.push(ship_type);
	}

	// the path to the `.lua` script file
	const file_path = path.resolve(__dirname, `../scripts/modkit/ship-types.lua`);
	
	// string contents of the file
	const target_content = (await fs.readFile(file_path)).toString();

	const replace_pattern = /modkit.ship_types = {[\s\S]*};/gm;

	// original table
	const orignal_line = target_content.match(replace_pattern)[0];

	const parsed = target_content.replace(replace_pattern, `modkit.ship_types = ${objToLuaTable(ship_types, 1)};`);

	// console.log(parsed);

	await fs.writeFile(
		file_path,
		parsed,
		{
			flag: 'w'
		}
	);
})();