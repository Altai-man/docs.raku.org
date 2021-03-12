use Cro::WebApp::Template;
use Pod::To::HTML;

class Docky::Renderer::Page does Pod::To::HTML::Renderer {
    method render(%context) {
        render-template 'content.crotmp', %context;
    }
}
