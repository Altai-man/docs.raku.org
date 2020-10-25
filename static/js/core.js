$(function(){
    setup_glot_io();
    setup_sidebar();
    setup_search();
});

function setup_glot_io() {
    // CodeMirror editor is enabled on click
    $('pre').each(function(i, el) {
        $(el).click(function () {
            var $el = $(this);
            // If already editor, return
            if ($el.find('.CodeMirror').length != 0) { return; }
            // If not a Raku snippet, return
            if (!$el.parent().hasClass('raku-lang')) { return; }
            CodeMirror(el, {
                lineNumbers:    true,
                lineWrapping:   true,
                mode:           'perl6',
                scrollbarStyle: 'null',
                theme:          'ayaya',
                value:          $el.find('code').text().trim()
            });
            $el.find('code').text('');
        });
    });

    // Run code button
    $('.code-button').each(function(i, el) {
        $(el).click(function() {
            var code = '';
            var output_top = '<p class="code-output-title">Output</p>';
            $(this).closest('.raku-code').find('.CodeMirror-code .CodeMirror-line').each(function(i, el){ code += $(el).text() + "\n"; });
            if (code.length == 0) {
                $(this).closest('.raku-code').find('code').each(function(i, el){ code += $(el).text() + "\n"; });
            }

            jQuery.ajax('/run', {
                method: 'POST',
                success: function(data) {
                    $(el).closest('.raku-code').find('.code-output').each(function(i, el) {
                        $(el).find('div').html(output_top + data);
                    });
                },
                data: { code: code },
                error: function(req, error) {
                    $(el).closest('.raku-code').find('.code-output').each(function(i, el) {
                        $(el).find('div').html(output_top + 'Error occurred: ' + error);
                    });
                }
            });
        });
    });
}

var base_width, toggle_width, sidebar_is_shown;

function setup_sidebar() {
    sidebar_is_shown = JSON.parse(window.localStorage.getItem('raku-docs-sidebar'));
    if (sidebar_is_shown === null) {
        sidebar_is_shown = true;
        window.localStorage.setItem('raku-docs-sidebar', sidebar_is_shown);
    }
    else if (!sidebar_is_shown) {
        hide_sidebar($('.raku-sidebar-toggle')[0]);
    }

    function hide_sidebar(el) {
        var svg = $(el).find('svg')[0];
        if (svg !== undefined) {
            svg.setAttribute('data-icon', 'chevron-right');
        }
        base_width = $("#mainSidebar").css('width');
        $("#mainSidebar").css('width', '0');
        $("#mainSidebar").css('display', 'none');
        toggle_width = $(el).css('left');
        $(el).css('left', '0');
    }

    function show_sidebar(el) {
        var svg = $(el).find('svg')[0];
        if (svg !== undefined) {
            svg.setAttribute('data-icon', 'chevron-left');
        }
        $("#mainSidebar").css('width', base_width);
        $("#mainSidebar").css('display', 'block');
        $(el).css('left', toggle_width);
    }

    // Sidebar toggle
    $('.raku-sidebar-toggle').each(function(i, el) {
        $(el).click(function() {
            if (sidebar_is_shown) {
                sidebar_is_shown = false;
                hide_sidebar(el);
            } else {
                sidebar_is_shown = true;
                show_sidebar(el);
            }
            window.localStorage.setItem('raku-docs-sidebar', sidebar_is_shown);
        });
    });

    $(".tab-switch").each(function(i, el) {
        $(el).click(function () {
            $('.tab-switch').each(function(i, el) {
                $(el).removeClass('is-active');
            });
            var tab_id = 'tab-' + $(el).attr('id').substring(7);
            $('.tabcontent').each(function(i, el) {
                $(el).css('display', 'none');
            });
            $(el).addClass('is-active');
            $('#' + tab_id).css('display', 'block');
        });
    });

    var originalTOC = $('#toc-menu').html();

    $("#toc-filter").keyup(function() {
        $('#toc-menu').html(originalTOC);
        var searchText = this.value.toLowerCase();
        if (searchText.length === 0) return;
        var $allListElements = $('#toc-menu > ul > li');
        var $matchingListElements = $allListElements.filter(function(i, li) {
            var listItemText = $(li).text();
            var fuzzyRes = fuzzysort.go(searchText, [listItemText])[0];
            if (fuzzyRes === undefined || fuzzyRes.score < -8000) {
                return false;
            }
            var res = fuzzysort.highlight(fuzzyRes);
            console.log(res);
            if (res !== null) {
                var nodes = $(li).contents().filter(function(i, node){ return node.nodeType == 1; });

                if (nodes.length === 1) {
                    console.log(nodes);
                    nodes[0].innerHTML = res;
                }
                return true;
            } else {
                return false;
            }
        });
        $allListElements.hide();
        $matchingListElements.show();
    });
}

var current_search = "";

function searchResultsComparator(a, b) {
    // We want to place 5to6 docs to the end of the list.
    // See if either a or b are in 5to6 category.
    var isp5a = false, isp5b = false;
    if (a.category.substr(0,4) == '5to6') { isp5a = true; }
    if (b.category.substr(0,4) == '5to6') { isp5b = true; }

    // If one of the categories is a 5to6 but other isn't,
    // move 5to6 to be last
    if (isp5a  && !isp5b) {return  1;}
    if (!isp5a && isp5b ) {return -1;}

    // Sort by category alphabetically; 5to6 items would both have
    // the same category if we reached this point and category sort
    // will happen only on non-5to6 items
    var a_cat = a.category.toLowerCase();
    var b_cat = b.category.toLowerCase();
    if (a_cat < b_cat) {return -1;}
    if (a_cat > b_cat) {return  1;}

    // We reach this point when categories are the same; so
    // we sort items by value

    var a_val = a.value.toLowerCase();
    var b_val = b.value.toLowerCase();

    // exact matches preferred
    if (a_val == current_search) {return -1;}
    if (b_val == current_search) {return  1;}

    var a_sw = a_val.startsWith(current_search);
    var b_sw = b_val.startsWith(current_search);
    // initial matches preferred
    if (a_sw && !b_sw) { return -1;}
    if (b_sw && !a_sw) { return  1;}

    // default
    if (a_val < b_val) {return -1;}
    if (a_val > b_val) {return  1;}

    return 0;
}

function setup_search() {
    // Customize search results rendering
    $.widget("custom.catcomplete", $.ui.autocomplete, {
        _create: function() {
            this._super();
            this.widget().menu("option", "items", "> :not(.ui-autocomplete-category)");
        },
        _renderItem: function(ul, item) {
            // This JS-regex-escapes current search string and looks it up in an item to
            // make this substring bold.
            // FIXME wants fuzzysearch or similar
            var regex = new RegExp('(' + current_search.replace(/[-[\]{}()*+?.,\\^$|#\s]/g, '\\$&') + ')', 'ig');
            var text = item.label.replace(regex, '<b>$1</b>');
            return $("<li>").append($("<div>").html(text)).appendTo(ul);
        },
        _renderMenu: function(ul, items) {
            var that = this, currentCategory = "";
            var sortedItems = items.sort(searchResultsComparator);
            var keywords = $("#query").val();
            sortedItems.push({
                category: 'Site Search',
                label: "Search the entire site for '" + keywords + "'",
                value: keywords,
                url: siteSearchUrl(keywords)
            });
            $.each(sortedItems, function(index, item) {
                if (item.category != currentCategory) {
                    ul.append("<li class='ui-autocomplete-category'>" + item.category + "</li>");
                    currentCategory = item.category;
                }
                var li = that._renderItemData(ul, item);
                if (item.category) {
                    li.attr("aria-label", item.category + " : " + item.label);
                }
            });
        },
    });

    // Set search autocomplete hook
    $("#query").attr('placeholder', '🔍').catcomplete({
        response: function(e, ui) {
            if (! ui.content.length) {
                $('#search').addClass('not-found')
                    .find('#try-web-search').attr(
                        'href', siteSearchUrl($("#query").val())
                   );
            }
            else {
                $('#search').removeClass('not-found');
            }
      },
      open: function() {
        var ui_el = $('.ui-autocomplete');
        if (ui_el.offset().left < 0) {
            ui_el.css({left: 0});
        }
      },
      source: function(request, response) {
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
              } ];
          var results = $.ui.autocomplete.filter(items, request.term);
          function trim_results(results, term) {
              var cutoff = 50;
              if (results.length < cutoff) {
                  return results;
              }
              // Prefer exact matches, then starting matches.
              var exacts = [];
              var prefixes = [];
              var rest = [];
              for (var ii = 0; ii <results.length; ii++) {
                  if (results[ii].value.toLowerCase() == term.toLowerCase()) {
                      exacts.push(ii);
                  } else if (results[ii].value.toLowerCase().startsWith(term.toLowerCase())) {
                  prefixes.push(ii);
                  } else {
                      rest.push(ii);
                  }
              }
              var keeps = [];
              var pos = 0;
              while (keeps.length <= cutoff && pos < exacts.length) {
                  keeps.push(exacts[pos++]);
              }
              pos = 0;
              while (keeps.length <= cutoff && pos < prefixes.length) {
                  keeps.push(prefixes[pos++]);
              }
              pos = 0;
              while (keeps.length <= cutoff && pos < rest.length) {
                  keeps.push(rest[pos++]);
              }
              var filtered = [];
              for (pos = 0; pos < results.length; pos++) {
                  if (keeps.indexOf(pos) != -1) {
                      filtered.push(results[pos]);
                  }
              }
              return filtered;
          };
          response(trim_results(results, request.term));
      },
      select: function (event, ui) { window.location.href = ui.item.url; },
      autoFocus: true
  });
};

function siteSearchUrl(keywords) {
    return 'https://www.google.com/search?q=site%3Adocs.raku.org+' + encodeURIComponent(keywords);
}
