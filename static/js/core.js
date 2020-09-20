$(function(){
    setup_glot_io();
});

function setup_glot_io() {
    $('pre').each(function(i, el) {
        var $el = $(el);
        if (!$el.parent().hasClass('raku-lang')) {
            return;
        }
        var mirror = CodeMirror(el, {
            lineNumbers:    true,
            lineWrapping:   true,
            mode:           'perl6',
            scrollbarStyle: 'null',
            theme:          'ayaya',
            value:          $el.find('code').text().trim()
        });
        $el.find('code').text('')
    });

    $('.code-button').each(function(i, el) {
        $(el).click(function() {
            var code = '';
            var output_top = '<p class="code-output-title">Output</p>';
            $(this).closest('.raku-code').find('.CodeMirror-code .CodeMirror-line').each(function(i, el){ code += $(el).text() + "\n"; });

            jQuery.ajax('/run', {
                method: 'POST',
                success: function(data) {
                    $(el).closest('.raku-code').find('.code-output').each(function(i, el){
                        $(el).html(output_top + data); $(el).show();
                    });
                },
                data: { code: code },
                error: function(req, error) {
                    $(el).closest('.raku-code').find('.code-output').each(function(i, el){
                        $(el).html(output_top + 'Error occurred: ' + error); $(el).show();
                    });
                }
            });
        });
    });

}

// Open navbar menu
document.addEventListener('DOMContentLoaded', () => {

    // Get all "navbar-burger" elements
    const $navbarBurgers = Array.prototype.slice.call(document.querySelectorAll('.navbar-burger'), 0);

    // Check if there are any navbar burgers
    if ($navbarBurgers.length > 0) {

        // Add a click event on each of them
        $navbarBurgers.forEach( el => {
            el.addEventListener('click', () => {

                // Get the target from the "data-target" attribute
                const target = el.dataset.target;
                const $target = document.getElementById(target);

                // Toggle the "is-active" class on both the "navbar-burger" and the "navbar-menu"
                el.classList.toggle('is-active');
                $target.classList.toggle('is-active');

            });
        });
    }
});
