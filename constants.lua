require "__DragonIndustries__.strings"

--no research = 2 types
ITEM_COUNT_TIERS = {5, 10, 25, 50, 100, 200, 500, 1000}

--no research = 1 slot per item type
SLOT_COUNT_TIERS = {2, 5, 10, 25, 50, 100, 250, 500, 1000}

CATEGORY_FRACTIONS = {
	["intermediate-products"] = 0.5, --includes bob
	["logistics"] = 0.15, --includes bob
	["production"] = 0.05,
	["combat"] = 0.1,
	["other"] = 0.2,
}

function getFractionCategoryForItem(item)
	local cat = getItemCategory(item)
	if CATEGORY_FRACTIONS[cat] then return cat end
	cat = literalReplace(cat, "bob-", "")
	if CATEGORY_FRACTIONS[cat] then return cat end
	if cat == "resource-products" then return "intermediate-products" end --one of bob intermediates
	if cat == "gems" then return "intermediate-products" end --bob gems
	return "other"
end

WAGON_SLOT_TIERS = {2, 5, 10, 20, 40, 80, 120, 200} --gui is 10 slots wide; no research = 1 slot per wagon; 200 slots is basically "any"