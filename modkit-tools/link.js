// link-all.js
// Node script which links every ship in the stock lineup to modkit's driver
// Without this, modkit is still extremely useful for code organisation, but ships which are not
// linked to modkit will not appear in the `GLOBAL_REGISTRY` (you can obviously still work with them via
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
						// custom code hook
						await fs.appendFile(target_file, `\n\n${linkCustomCode(type)}`);
	
						// custom ability hook
						const ab_code = linkAbilityCode(type);
						if (ab_code) {
							await fs.appendFile(target_file, ab_code);
						}
	
						// register the ship's filename in modkit.ship_types
						// await fs.appendFile(target_file, linkModkitRegister(type));
					}
				}

				
			}
			rimraf.sync(path.resolve(__dirname, `/ship`));
			progress_bar.stop();
			console.log(`[modkit] link.js: ${already_existed_count} files appended; ${didnt_exist_count} files newly created`);
			console.log(`[modkit] link.js: \t(Pre-existing .ship files have had a line appended but are otherwise unharmed!)`);
		}
		console.log(`[modkit] link.js: remove src: ${src_ships_dir}`);
		rimraf.sync(src_ships_dir);
		console.log("[modkit] link.js: finished! ✨")
	} catch (err) {
		console.log(err);
	}
})();