-- Offline unit tests for `scripts/modkit/string_util.lua` (the global `str*` functions). Run with `npm test` in `modkit-tools`.

dofile("modkit-tools/tests/lua/harness.lua");
loadQuietly("scripts/modkit/table_util.lua"); -- (`strsplit` and `strimplode` use `modkit.table`)
loadQuietly("scripts/modkit/string_util.lua");

describe("strsplit", function ()
	describe("with return_words_only", function ()
		it("splits on whitespace by default", function ()
			expectEq(strsplit("move  to   here", nil, 1), { "move", "to", "here" });
		end);
		it("splits on a given delimiter", function ()
			expectEq(strsplit("a,b,c", ",", 1), { "a", "b", "c" });
		end);
		it("ignores leading, trailing, and repeated delimiters", function ()
			expectEq(strsplit(",,a,,b,", ",", 1), { "a", "b" });
		end);
		it("keeps single-character words, including the last", function ()
			expectEq(strsplit("a b c", " ", 1), { "a", "b", "c" });
			expectEq(strsplit("ab c", " ", 1), { "ab", "c" });
		end);
		it("returns the whole string when there's no delimiter in it", function ()
			expectEq(strsplit("word", " ", 1), { "word" });
			expectEq(strsplit("x", " ", 1), { "x" });
		end);
		it("returns the whole string for an empty string, or one made only of delimiters", function ()
			expectEq(strsplit("", " ", 1), { "" });
			expectEq(strsplit("   ", " ", 1), { "   " });
		end);
		it("treats the delimiter as a pattern (so '%s+' splits on runs of whitespace, and keeps '+')", function ()
			-- (`commands.lua` passes "%s+" to split vectors)
			expectEq(strsplit("10  +5\t-3", "%s+", 1), { "10", "+5", "-3" });
		end);
		it("splits on multi-character and escaped delimiters", function ()
			expectEq(strsplit("a, b, c", ", ", 1), { "a", "b", "c" });
			expectEq(strsplit("a.b.c", "%.", 1), { "a", "b", "c" });
			expectEq(strsplit("a+b", "+", 1), { "a", "b" });
		end);
		it("treats a delimiter which can match nothing as matching nowhere", function ()
			expectEq(strsplit("a b", "%s*", 1), { "a b" });
		end);
	end);

	describe("without return_words_only", function ()
		it("returns { start, finish, str } for each word", function ()
			expectEq(strsplit("ab cd", " "), {
				{ start = 1, finish = 2, str = "ab" },
				{ start = 4, finish = 5, str = "cd" },
			});
		end);
		it("gives positions in the original string when delimiters span several characters", function ()
			expectEq(strsplit("ab   cd", "%s+"), {
				{ start = 1, finish = 2, str = "ab" },
				{ start = 6, finish = 7, str = "cd" },
			});
		end);
		it("returns the whole string as one entry when there's no delimiter in it", function ()
			expectEq(strsplit("word", " "), { { start = 1, finish = 4, str = "word" } });
		end);
	end);
end);

describe("strcharset", function ()
	it("replaces the character at index", function ()
		expectEq(strcharset("abc", 1, "X"), "Xbc");
		expectEq(strcharset("abc", 2, "X"), "aXc");
		expectEq(strcharset("abc", 3, "X"), "abX");
	end);
	it("can replace a character with a longer string, or remove it", function ()
		expectEq(strcharset("abc", 2, "XYZ"), "aXYZc");
		expectEq(strcharset("abc", 2, ""), "ac");
	end);
end);

describe("strimplode", function ()
	it("joins a list with the delimiter between entries", function ()
		expectEq(strimplode({ "a", "b", "c" }, ", "), "a, b, c");
	end);
	it("joins with no delimiter by default", function ()
		expectEq(strimplode({ "a", "b", "c" }), "abc");
	end);
	it("keeps the list's order, without a trailing delimiter, for longer lists", function ()
		local words = {};
		local expected = "";
		for i = 1, 40 do
			words[i] = "w" .. i;
			expected = expected .. ((i > 1 and ",") or "") .. "w" .. i;
		end
		expectEq(strimplode(words, ","), expected);
	end);
	it("returns the only entry without a delimiter, and an empty string for an empty list", function ()
		expectEq(strimplode({ "a" }, ","), "a");
		expectEq(strimplode({}, ","), "");
	end);
end);

describe("struid", function ()
	it("is 8 characters by default", function ()
		expectEq(strlen(struid()), 8);
	end);
	it("is `length` characters when given", function ()
		expectEq(strlen(struid(3)), 3);
		expectEq(strlen(struid(20)), 20);
	end);
	it("only uses [0-9a-z]", function ()
		randomseed(1);
		for _ = 1, 50 do
			local id = struid();
			expectNil(strfind(id, "[^0-9a-z]"), "id '" .. id .. "' has a character outside [0-9a-z]");
		end
	end);
end);

describe("strtrim", function ()
	it("removes leading and trailing whitespace", function ()
		expectEq(strtrim("  hi there \t\n"), "hi there");
	end);
	it("leaves a string without surrounding whitespace alone", function ()
		expectEq(strtrim("hi"), "hi");
		expectEq(strtrim(""), "");
	end);
	it("returns only the string (not gsub's replacement count too)", function ()
		local trimmed, extra = strtrim(" hi ");
		expectEq(trimmed, "hi");
		expectNil(extra, "a second return value");
	end);
end);

finish();
