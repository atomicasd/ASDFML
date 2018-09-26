local oh = ... or _G.oh
local syntax = {}

do -- syntax rules
	syntax.double_quote = "\""
	syntax.single_quote = "'"
	syntax.literal_quote = "`"
	syntax.escape_character = "\\"
	syntax.comment = "--"

	syntax.cpp_comment = "//"
	syntax.c_comment_start = "/*"
	syntax.c_comment_stop = "*/"

	syntax.space = {"", " ", "\n", "\r", "\t"}

	syntax.number = {}
	for i = 0, 9 do
		syntax.number[i+1] = tostring(i)
	end

	syntax.letter = {"_"}
	for i = string.byte("A"), string.byte("z") do
		table.insert(syntax.letter, string.char(i))
	end

	syntax.keywords = {
		"and", "break", "do", "else", "elseif", "end",
		"false", "for", "function", "if", "in", "local",
		"nil", "not", "or", "repeat", "return", "then",
		"true", "until", "while", "goto", "...",
	}

	syntax.keyword_values = {
		"...",
		"nil",
		"true",
		"false",
	}

	syntax.symbol = {".", ",", "(", ")", "{", "}", "[", "]",
		"=", ":", ";", "~", "::",
		"...", syntax.single_quote, syntax.double_quote,
		syntax.literal_quote,
	}

	syntax.unary_operators = {
		["+"] = -10,
		["-"] = -10,
		["#"] = -10,
		["not"] = -10,
		["!"] = -10,
		["~"] = -10,
	}

	syntax.operators = {
		["or"] = 1, ["||"] = 1,
		["and"] = 2, ["&&"] = 2,
		["<"] = 3, [">"] = 3, ["<="] = 3, [">="] = 3, ["~="] = 3, ["!="] = 3, ["=="] = 3,
		["|"] = 4,
		-- ~ is in the manual here but isn't it a unary operator?
		["&"] = 5,
		["<<"] = 6, [">>"] = 6,
		[".."] = -7, -- right associative
		["+"] = 8, ["-"] = 8,
		["*"] = 9, ["/"] = 9, ["%"] = 9,
		-- the unary operators are in the manual here
		["^"] = -11, -- right associative
	}

	syntax.operator_function_transforms = {
		[">>"] = "bit.rshift",
		["<<"] = "bit.lshift",
		["&"] = "bit.band",
		["|"] = "bit.bor",
		["~"] = "bit.bnot",
		["^^"] = "bit.bxor",
	}

	syntax.operator_translate = {
		["||"] = "or",
		["&&"] = "and",
		["!="] = "~=",
		["!"] = "not",
	}

	function syntax.IsValue(token)
		return token.type == "number" or token.type == "string" or syntax.keyword_values[token.value]
	end

	function syntax.GetLeftOperatorPriority(token)
		return oh.syntax.operators[token.value] and oh.syntax.operators[token.value][1]
	end

	function syntax.GetRightOperatorPriority(token)
		return oh.syntax.operators[token.value] and oh.syntax.operators[token.value][2]
	end

	function syntax.IsUnaryOperator(token)
		return syntax.unary_operators[token.value]
	end

	do
		local char_types = {}

		for _, type in ipairs({"number", "letter", "space", "symbol"}) do
			for _, value in ipairs(syntax[type]) do
				char_types[value] = type
			end
		end

		syntax.char_types = char_types
	end

	for i,v in pairs(syntax.operators) do
		if v < 0 then
			syntax.operators[i] = {-v + 1, -v}
		else
			syntax.operators[i] = {v, v}
		end
	end

	for i,v in pairs(syntax.unary_operators) do
		if v < 0 then
			syntax.operators[i] = {-v + 1, -v}
		else
			syntax.operators[i] = {v, v}
		end
	end

	for k,v in pairs(syntax.keywords) do
		syntax.keywords[v] = v
	end

	for k,v in pairs(syntax.keyword_values) do
		syntax.keyword_values[v] = v
	end

	do
		local done = {}
		for k,v in pairs(syntax.operators) do
			if not done[k] then
				table.insert(syntax.symbol, k)
				done[k] = true
			end
		end
		table.sort(syntax.symbol, function(a, b) return #a > #b end)

		local longest_symbol = 0
		local lookup = {}
		for k,v in ipairs(syntax.symbol) do
			lookup[v] = true
			longest_symbol = math.max(longest_symbol, #v)
			if #v == 1 then
				syntax.char_types[v] = "symbol"
			end
		end
		syntax.longest_symbol = longest_symbol
		syntax.symbols_lookup = lookup
	end
end

oh.syntax = syntax

if RELOAD then
	oh.Test()
end