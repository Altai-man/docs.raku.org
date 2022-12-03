var items = [
    {
        category: "Syntax",
        value: "# single-line comment",
        url: "/language/syntax#Single-line_comments"
    }, {
        category: "Syntax",
        value: "#` multi-line comment",
        url: "/language/syntax#Multi-line_/_embedded_comments"
    }, {
        category: "Signature",
        value: ";; (long name)",
        url: "/type/Signature#index-entry-Long_Names"
    }, ITEMS ];

const navbarSearchEmptyElement = document.createElement('li');
navbarSearchEmptyElement.className = 'navbar-search-empty autocomplete-result has-text-primary';
navbarSearchEmptyElement.textContent = 'Not found, but you can try site search';
const navbarSiteSearchElement = document.createElement('li');
navbarSiteSearchElement.className = 'navbar-site-search autocomplete-result has-text-primary';

const autoCompleteConfig = {
    name: "autocomplete",
    selector: "#query",
    data: {
        src: items,
        keys: ['value'],
        filter: list => {
            const inputValue = autoCompleteJS.input.value;

            list = searchCategory(inputValue, list);

            list.sort((a, b) => {
                const aValue = a.value.value;
                const bValue = b.value.value;

                const aDistance = levenshteinDistance(inputValue, aValue);
                const bDistance = levenshteinDistance(inputValue, bValue);

                if (aDistance === bDistance) return aValue > bValue;

                return aDistance < bDistance ? -1 : 1;
            });

            // Prioritize results which start with query
            list.sort((a, b) => {
                const aValue = a.value.value;
                const bValue = b.value.value;

                if (aValue.startsWith(inputValue)) {
                    return -1;
                } else if (bValue.startsWith(inputValue)) {
                    return 1;
                }
                return 0;
            });

            return list;
        }
    },
    query: stripSigns,
    searchEngine: 'loose',
    resultsList: {
        element: (list, data) => {
            if (data.results.length === 0) {
                list.appendChild(navbarSearchEmptyElement);
            } else {
                navbarSiteSearchElement.innerHTML = `<span class="autocomplete-result-match">
                             Search the entire site for ${data.query}
                             </span>
                             <span class="autocomplete-result-category">Site Search</span>`;
                list.appendChild(navbarSiteSearchElement);
            }

            // Go to the first result
            autoCompleteJS.goTo(0);
        },
        class: 'navbar-search-autocomplete',
        position: "afterend",
        noResults: true,
        maxResults: 200
    },
    resultItem: {
        element: (item, data) => {
			item.innerHTML = `<span class="autocomplete-result-match">
                             ${data.match}
                             </span>
                             <span class="autocomplete-result-category">
                             ${data.value.category}
                             </span>`;
		},
        class: 'autocomplete-result',
        highlight: true
    },
    events: {
        input: {
            focus: _event => {
                autoCompleteJS.open();
            }
        }
    }
};

const autoCompleteJS = new autoComplete({ ...autoCompleteConfig });

const queryElement = document.querySelector("#query");

queryElement.addEventListener("selection", function (event) {
    // "event.detail" carries the autoComplete.js "feedback" object

    const numberOfResults = event.detail.results.length;
    if (numberOfResults && event.detail.selection.index != numberOfResults) {
        location.href = event.detail.selection.value.url;
    } else {
        location.href = siteSearchUrl(event.detail.query);
    }
});

const method_sign = new RegExp(/^\.\w[\w-]*/);
const routine_sign = new RegExp(/^&\w[\w-]*.*/);
const routineMethod_sign = new RegExp(/[^(]+\(\)?$/);
const classPackageRole_sign = new RegExp(/^::[A-Z][\w:]*/);

function stripSigns (query) {
    switch (true) {
    case method_sign.test(query):
        // We matched `.`, strip it off
        return query.substring(1);
    case routine_sign.test(query):
        // We matched a &, strip it off
        return query.replace('&', '');
    case routineMethod_sign.test(query):
        // We matched (), strip it off
        return query.replace(/[()]/g, '');
    case classPackageRole_sign.test(query):
        // We matched ::, strip it off
        return query.replace('::', '');
    default:
        return query;
    }
}

function searchCategory (query, items) {
    switch (true) {
    case method_sign.test(query):
        return filterByCategory(items, 'methods', 'routines');
    case routine_sign.test(query):
        return filterByCategory(items, 'subroutines', 'routines');
    case routineMethod_sign.test(query):
        return filterByCategory(items, 'methods', 'subroutines');
    case classPackageRole_sign.test(query):
        return filterByCategory(items, 'types');
    default:
        return items;
    }
}

function filterByCategory (items, ...categories) {
    return items.filter(item => {
        return categories.some(category => category === item.value.category.toLowerCase());
    });
}

function siteSearchUrl (keywords) {
    return 'https://www.google.com/search?q=site%3Adocs.raku.org+' + encodeURIComponent(keywords);
}

// https://dirask.com/posts/JavaScript-calculate-Levenshtein-distance-between-strings-pJ3krj
function levenshteinDistance (a, b) {
  	const c = a.length + 1;
  	const d = b.length + 1;
  	const r = Array(c);
  	for (let i = 0; i < c; ++i) r[i] = Array(d);
    for (let i = 0; i < c; ++i) r[i][0] = i;
    for (let j = 0; j < d; ++j) r[0][j] = j;
    for (let i = 1; i < c; ++i) {
        for (let j = 1; j < d; ++j) {
            const s = (a[i - 1] === b[j - 1] ? 0 : 1);
          	r[i][j] = Math.min(r[i - 1][j] + 1, r[i][j - 1] + 1, r[i - 1][j - 1] + s);
        }
    }
  	return r[a.length][b.length];
}
