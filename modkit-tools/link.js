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

const linkCode = (type) => `addCustomCode(NewShipType, "data:scripts/driver.lua", "load", "create", "update", "destroy", "${type}", 1);`;

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
		const emitter = degit(`novaras/ships-vanilla`, {
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
			const paths = await globby([`./modkit-tools/ship/**/*.ship`]);
			const progress_bar = new cli_prog.SingleBar({
				format: `Writing .ship files: [{bar}] {percentage}% | {value}/{total} (ETA: {eta}s)`,
				clearOnComplete: false,
			}, cli_prog.Presets.rect);

			let didnt_exist_count = 0;
			let already_existed_count = 0;
			progress_bar.start(paths.length, 0);
			for (const [index, file_path] of paths.entries()) {
				progress_bar.update(index);

				const parts = file_path.split(`/`);
				const target_file = path.resolve(__dirname, `../ship/${parts.slice(-2).join(`/`)}`);
				const target_dir = path.resolve(__dirname, `../ship/${parts.slice(-2, -1).join(`/`)}`);

				try {
					await fs.mkdir(target_dir, { recursive: true });
				} catch (err) {
					console.error(err);
				}

				try {
					await fs.writeFile(
						target_file,
						await fs.readFile(file_path),
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
				await fs.appendFile(target_file, `\n\n${linkCode(parts.slice(-1)[0].split(`.`)[0])}`);
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