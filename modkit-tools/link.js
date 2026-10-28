// link.js
// Node script which links every ship in the stock lineup to modkit's driver
// Without this, modkit is still extremely useful for code organisation, but ships which are not
// linked to modkit will not appear in `GLOBAL_SHIPS` (you can obviously still work with them via
// plain SobGroup_ calls).

const fs = require("fs").promises;
const path = require("path");
const prompts = require("prompts");
const globby = require("globby");
const rimraf = require("rimraf");
const degit = require("degit");
const cli_prog = require("cli-progress");

/**
 * 
 * @param { string } type 
 */
const linkCustomCode = (type) => {
	const load = type.substring(4) === `researchship` ? `load_${type.substring(0, 3)}_res_ship` : `load`;
	return `addCustomCode(NewShipType, "data:scripts/driver.lua", "${load}", "create", "update", "destroy", "${type}", 1);`;
};

const linkAbilityCode = (type) => {
	if (![`kus`, `tai`].includes(type.substring(0, 3))) {
		return null;
	}
	const generic = type.substring(4);
	const confs = {
		'scout': {
			label: `"Speed Burst"`,
			energy_params: `1, 0, 1200, 1200, 12, 3, 200`,
			extra: `1, 3, 1`,
		},
		'gravwellgenerator': {
			label: `"Gravity Well"`,
			energy_params: `1,0,166,1,0.65,0.0,300`,
			extra: `1.0,1,1,1,1`,
		}
	};
	const conf = confs[generic];
	if (!conf) return null;

	return `\naddAbility(NewShipType, "CustomCommand", 1, ${conf.label}, ${conf.energy_params}, "data:scripts/driver.lua", "start", "go", "finish", "${type}", ${conf.extra});`;
};

/**
 * The possible results of `linkShipFile`.
 *
 * @readonly
 * @enum { string }
 */
const LinkResult = Object.freeze({
	/** modkit's lines were appended */
	LINKED: `linked`,
	/** the ship already had modkit's `addCustomCode` line, so nothing was appended */
	ALREADY_LINKED: `already_linked`,
	/** modkit's lines were appended, but the ship already had its own (non-modkit) `addCustomCode` call, which the modder should check */
	OWN_CUSTOM_CODE: `own_custom_code`,
});

/**
 * Appends modkit's `addCustomCode` (and custom ability, if any) lines to a `.ship` file, unless it's already linked,
 * so re-running this script doesn't link a ship twice.
 *
 * @param { string } target_file
 * @param { string } type i.e 'hgn_scout'
 * @returns { Promise<LinkResult> }
 */
const linkShipFile = async (target_file, type) => {
	const content = (await fs.readFile(target_file)).toString();
	const custom_code_calls = content.match(/^\s*addCustomCode.+$/gmi) || [];
	if (custom_code_calls.some(call => call.includes(`data:scripts/driver.lua`))) {
		return LinkResult.ALREADY_LINKED;
	}

	await fs.appendFile(target_file, `\n\n${linkCustomCode(type)}`);

	const ab_code = linkAbilityCode(type);
	if (ab_code && !/^\s*addAbility\(NewShipType,\s*"CustomCommand"/mi.test(content)) {
		await fs.appendFile(target_file, ab_code);
	}

	return custom_code_calls.length > 0 ? LinkResult.OWN_CUSTOM_CODE : LinkResult.LINKED;
};

/**
 * Logs a summary of `linkShipFile` results.
 *
 * @param { Map<string, LinkResult> } results ship type => result
 */
const logLinkResults = (results) => {
	const typesWith = (result) => [...results].filter(([, r]) => r === result).map(([type]) => type);

	const linked = typesWith(LinkResult.LINKED);
	const already_linked = typesWith(LinkResult.ALREADY_LINKED);
	const own_custom_code = typesWith(LinkResult.OWN_CUSTOM_CODE);

	console.log(`[modkit] link.js: ${linked.length + own_custom_code.length} ships linked; ${already_linked.length} skipped (already linked)`);
	if (own_custom_code.length > 0) {
		console.log(`[modkit] link.js: these ships already had their own addCustomCode call as well, so check they still behave as intended:`);
		for (const type of own_custom_code) {
			console.log(`\t${type}`);
		}
	}
};

(async () => {
	console.log("[modkit] link.js: start! 🔗");

	const only = process.argv[2];

	console.log(`DIRNAME: ${__dirname}`);
	const src_ships_dir = path.resolve(__dirname, `./ship`);

	const full_content = (await prompts([
		{
			type: `select`,
			name: `full`,
			message: `Generate missing vanilla ship files if they don't exist?`,
			choices: [
				{
					title: `Generate missing vanilla ship files where needed.`,
					value: true,
				},
				{
					title: `Append addCustomCode to existing ships only.`,
					value: false
				}
			]
		}
	])).full;

	console.log(full_content);

	if (full_content) {
		const emitter = degit(`novaras/ships-vanilla#all-ships`, {
			force: true,
			verbose: true,
		});

		emitter.on('info', info => {
			console.log(info.message);
		});

		await emitter.clone(__dirname);

		console.log('done');

		if (only) {
			const root = path.resolve(__dirname, `./ship`);
			const paths = await globby([`${root}/**/*.ship`]);
			for (const path of paths) {
				const parts = path.split(`/`);
				if (parts[parts.length - 2] == only) continue;
				rimraf.sync(parts.slice(0, parts.length - 1).join(`/`));
			}
		}
	}

	try {
		/** @type { Map<string, LinkResult> } ship type => result */
		const link_results = new Map();

		if (full_content) {
			const paths = await globby([`./modkit-tools/ship/**/*.ship`, `./modkit-tools/resources/**/*.*`]);
			const progress_bar = new cli_prog.SingleBar({
				format: `Writing .ship files: [{bar}] {percentage}% | {value}/{total} (ETA: {eta}s)`,
				clearOnComplete: false,
			}, cli_prog.Presets.rect);

			let didnt_exist_count = 0;
			let already_existed_count = 0;
			progress_bar.start(paths.length, 0);
			for (const [index, file_path] of paths.entries()) {
				progress_bar.update(index);

				/**
				 * @type string[]
				 */
				const parts = file_path.split(`/`);
				
				const extension = parts[parts.length - 1].split('.')[1];

				// clone any .lua scripts
				if (extension == 'lua') {
					const target_file = path.resolve(__dirname, `../${parts.slice(-3).join('/')}`);
					const target_dir = path.resolve(__dirname, `${parts.slice(-3, -1).join(`/`)}`);

					try {
						await fs.mkdir(target_dir, { recursive: true });
						await fs.copyFile(file_path, target_file);
					} catch (err) {
						console.error(err);
					}
				} else {

					// parts: `['.', 'modkit-tools', '<ship|resources>', '<ship_name>', '<ship_name'>.<ext>]`

					const target_file = path.resolve(__dirname, `../ship/${parts.slice(-2).join(`/`)}`);
					const target_dir = path.resolve(__dirname, `../ship/${parts.slice(-2, -1).join(`/`)}`);
					const type = parts.slice(-1)[0].split(`.`)[0]; // i.e 'hgn_scout' from 'hgn_scout.ship'

					try {
						await fs.mkdir(target_dir, { recursive: true });
					} catch (err) {
						console.error(err);
					}
	
					try {
						let content = await fs.readFile(file_path);
						
						// cleanse original calls if present
						if (type !== "modkit_scheduler") {
							content = content.toString();
							content = content.replace(/addCustomCode.+/gmi, '');
							content = content.replace(/addAbility\(NewShipType,\s*"CustomCommand".+/gmi, '');
						}

						if (type.substring(4) === 'defensefighter') {
							content = content.replace(/Fighter_vs_Fighter/gmi, 'frontal_defensefighter');
						}
	
						// create the .ship file
						await fs.writeFile(
							target_file,
							content,
							{
								flag: `ax`
							}
						);
						didnt_exist_count += 1;
					} catch (err) {
						if (err.code === `EEXIST`) {
							already_existed_count += 1;
						} else {
							console.error(err);
						}
					}
					
					// link custom code & custom ability calls
					if (parts[2] === 'ship') {
						link_results.set(type, await linkShipFile(target_file, type));
					}
				}


			}
			progress_bar.stop();
			console.log(`[modkit] link.js: ${already_existed_count} .ship files already existed; ${didnt_exist_count} newly created`);
			logLinkResults(link_results);
			console.log(`[modkit] link.js: \t(Pre-existing .ship files have had lines appended but are otherwise unharmed!)`);
		} else {
			// link the mod's own .ship files only
			const ship_files = await globby(`**/*.ship`, { cwd: path.resolve(__dirname, `../ship`), absolute: true });
			for (const target_file of ship_files) {
				const type = path.basename(target_file, `.ship`); // i.e 'hgn_scout' from 'hgn_scout.ship'
				link_results.set(type, await linkShipFile(target_file, type));
			}
			logLinkResults(link_results);
		}
		console.log(`[modkit] link.js: remove src: ${src_ships_dir}`);
		rimraf.sync(src_ships_dir);
		console.log("[modkit] link.js: finished! ✨")
	} catch (err) {
		console.log(err);
	}
})();