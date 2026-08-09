local Test = { total = 0, failed = 0 }

function Test.case(name, callback)
    Test.total = Test.total + 1
    local ok, err = pcall(callback)
    if ok then
        print("ok " .. Test.total .. " - " .. name)
        return
    end
    Test.failed = Test.failed + 1
    print("not ok " .. Test.total .. " - " .. name)
    print("  " .. tostring(err))
end

function Test.equal(actual, expected, message)
    if actual ~= expected then
        error((message or "values differ") .. ": expected " .. tostring(expected)
            .. ", got " .. tostring(actual), 2)
    end
end

function Test.truthy(value, message)
    if not value then error(message or "expected a truthy value", 2) end
end

function Test.falsy(value, message)
    if value then error(message or "expected a falsey value", 2) end
end

function Test.notEqual(actual, unexpected, message)
    if actual == unexpected then
        error((message or "values unexpectedly match") .. ": " .. tostring(actual), 2)
    end
end

function Test.contains(text, expected, message)
    if not tostring(text or ""):find(tostring(expected), 1, true) then
        error((message or "text does not contain expected value") .. ": " .. tostring(expected), 2)
    end
end

function Test.same(actual, expected, message)
    local function compare(a, b, seen)
        if type(a) ~= type(b) then return false end
        if type(a) ~= "table" then return a == b end
        if seen[a] == b then return true end
        seen[a] = b
        for key, value in pairs(a) do
            if not compare(value, b[key], seen) then return false end
        end
        for key in pairs(b) do
            if a[key] == nil then return false end
        end
        return true
    end
    if not compare(actual, expected, {}) then
        error(message or "tables differ", 2)
    end
end

return Test
