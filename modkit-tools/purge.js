// purge.js
// Clears out all modkit extras, such as tooling and readme files, leavin your mod in a clean state.

const fs = require("fs").promises;
const path = require("path");
const prompts = require("prompts");
const rimraf = require("rimraf");

const root = path.resolve(__dirname, "../");

const rmReadmes = () => {
	return Promise.all([
		".gitignore",
		"Driver.md",
		"MemGroup.md",
		"README.md",
		"init.bat"
	].map(file_name => {
		return new Promise((res, rej) => {
			rimraf(file_name, (err) => {
				if (err) rej(err);
				res();
			});
		});
	}));
};

(async () => {
	const also_tools = (await prompts([
		{
			name: `answer`,
			type: `confirm`,
			message: `Delete ./modkit-tools (including this script)?`,
			initial: true
		}
	])).answer;

	if (also_tools) {
		await rmReadmes();
		rimraf(`${root}/modkit-tools`, err => console.error(err));
	}
})();
