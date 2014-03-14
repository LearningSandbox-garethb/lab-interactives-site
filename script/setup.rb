#!/usr/bin/env ruby
require 'fileutils'
require 'yaml'
require 'optparse'

PROJECT_ROOT = File.expand_path('../..',  __FILE__)                if !defined? PROJECT_ROOT
SRC_PATH  = File.join(PROJECT_ROOT, 'src')                         if !defined? SRC_PATH
SRC_LAB_PATH  = File.join(PROJECT_ROOT, 'src', 'lab')              if !defined? SRC_LAB_PATH
CONFIG_PATH  = File.join(PROJECT_ROOT, 'config')                   if !defined? CONFIG_PATH
SCRIPT_PATH = File.join(PROJECT_ROOT, 'script')                    if !defined? SCRIPT_PATH
BIN_PATH  = File.join(PROJECT_ROOT, 'bin')                         if !defined? BIN_PATH
PUBLIC_PATH  = File.join(PROJECT_ROOT, 'public')                   if !defined? PUBLIC_PATH

FRAMEWORK_ROOT_URL_FOR = {
  "lab2.dev.concord.org" => "//lab2-framework.dev.concord.org/lab",
  "lab3.dev.concord.org" => "//lab3-framework.dev.concord.org/lab",
  "lab4.dev.concord.org" => "//lab4-framework.dev.concord.org/lab",
  "lab5.dev.concord.org" => "//lab5-framework.dev.concord.org/lab"
}


def render_file(filename, locals)
  contents = File.read(filename)
  Haml::Engine.new(contents).render(Object.new, locals)
end

LAB_ROOT_URL = {
  :production  => "//lab-framework.concord.org/lab",
  :staging     => "//lab-framework.staging.concord.org/lab",
  :development => "//lab-framework.dev.concord.org/lab",
  :topic_dev   => FRAMEWORK_ROOT_URL_FOR[ENV["LAB_HOST"]] || "//lab-framework.dev.concord.org/lab",
  :local       => "//localhost:9191/lab",
}

LAB_JS = {
  :production  => LAB_ROOT_URL[:production] + "/lab.min.js",
  :staging     => LAB_ROOT_URL[:staging] + "/lab.js",
  :development => LAB_ROOT_URL[:development] + "/lab.js",
  :topic_dev   => LAB_ROOT_URL[:topic_dev] + "/lab.js",
  :local       => LAB_ROOT_URL[:local] + "/lab.js"
}

LAB_CSS = {
  :production  => LAB_ROOT_URL[:production] + "/lab.css",
  :staging     => LAB_ROOT_URL[:staging] + "/lab.css",
  :development => LAB_ROOT_URL[:development] + "/lab.css",
  :topic_dev   => LAB_ROOT_URL[:topic_dev] + "/lab.css",
  :local       => LAB_ROOT_URL[:local] + "/lab.css"
}

EMBEDDABLE_PAGE = {
  :production  => "embeddable.html",
  :staging     => "embeddable-staging.html",
  :development => "embeddable-dev.html",
  :topic_dev   => "embeddable-topic-dev.html",
  :local       => "embeddable-local.html"
}

begin
  CONFIG = YAML.load_file(File.join(CONFIG_PATH, 'config.yml'))
rescue Errno::ENOENT
  msg = <<-HEREDOC

*** missing config/config.yml

    cp config/config.sample.yml config/config.yml

    and edit appropriately ...

  HEREDOC
  raise msg
end

# setup partial for Google Analytics
if CONFIG[:google_analytics] && CONFIG[:google_analytics][:account_id]
  ANALYTICS = <<-HEREDOC
  <script type="text/javascript">
    var _gaq = _gaq || [];
    _gaq.push(['_setAccount', '#{CONFIG[:google_analytics][:account_id]}']);
    _gaq.push(['_setAllowAnchor', true]);
    (function() {
    var ga = document.createElement('script'); ga.type = 'text/javascript'; ga.async = true;
    ga.src = ('https:' == document.location.protocol ? 'https://ssl' : 'http://www') + '.google-analytics.com/ga.js';
    var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(ga, s);
  })();
  </script>
  HEREDOC
else
  ANALYTICS = ""
end

JS_SITE_CONFIG =
  <<-HEREDOC
<script>
  var SITE_CONFIG = {
    LAB_ENV: null,
    SITE_ENV: "#{CONFIG[:environment]}",
    STATIC: #{!!(ENV['LAB_STATIC'] || CONFIG[:jsconfig][:static])},
    DATA_GAMES_PROXY_PREFIX: "#{CONFIG[:jsconfig][:dataGamesProxyPrefix]}",
  };
</script>
  HEREDOC

# setup partial for fontface
if CONFIG[:jsconfig] && CONFIG[:jsconfig][:fontface]
  FONTFACE = CONFIG[:jsconfig][:fontface]
else
  FONTFACE = 'Open Sans'
end

FONTFACE_LINK = case FONTFACE
when "Lato"
  <<-HEREDOC
<link href='//fonts.googleapis.com/css?family=Lato:300italic,700italic,300,400,400italic,700' rel='stylesheet' type='text/css'>
  HEREDOC
else          # default is "Open Sans"
  <<-HEREDOC
<link href='//fonts.googleapis.com/css?family=Open+Sans:400italic,700italic,300italic,400,300,700&amp;subset=latin,greek,latin-ext' rel='stylesheet' type='text/css'>
  HEREDOC
end

# setup partials for 'production' (minimized resources) or 'development'

LAB_JS_DEPENDENCIES = case CONFIG[:environment]
when 'production'
  <<-HEREDOC
<script src="vendor/d3/d3.min.js" type="text/javascript"></script>
<script src="vendor/jquery/jquery.min.js" type="text/javascript"></script>
<script src="vendor/jquery-ui/jquery-ui.min.js" type="text/javascript"></script>
<script src="vendor/jquery-ui-touch-punch/jquery.ui.touch-punch.min.js" type="text/javascript"></script>
<script src="vendor/jquery-context-menu/jquery.contextMenu.js" type="text/javascript"></script>
<script src="vendor/jquery-selectBoxIt/jquery.selectBoxIt.min.js" type="text/javascript"></script>
<script src='vendor/tinysort/jquery.tinysort.min.js' type='text/javascript'></script>
  HEREDOC
else
  <<-HEREDOC
<script src="vendor/d3/d3.js" type="text/javascript"></script>
<script src="vendor/jquery/jquery.js" type="text/javascript"></script>
<script src="vendor/jquery-ui/jquery-ui.js" type="text/javascript"></script>
<script src="vendor/jquery-ui-touch-punch/jquery.ui.touch-punch.js" type="text/javascript"></script>
<script src="vendor/jquery-context-menu/jquery.contextMenu.js" type="text/javascript"></script>
<script src="vendor/jquery-selectBoxIt/jquery.selectBoxIt.js" type="text/javascript"></script>
<script src='vendor/tinysort/jquery.tinysort.js' type='text/javascript'></script>
  HEREDOC
end

LAB_JS_ADDITIONAL_DEPENDENCIES = case CONFIG[:environment]
when 'production'
  <<-HEREDOC
<script src='vendor/iframe-phone/iframe-phone.js' type='text/javascript'></script>
<script src='vendor/codemirror/lib/codemirror.js' type='text/javascript'></script>
<script src='vendor/codemirror/mode/javascript/javascript.js' type='text/javascript'></script>
<script src='vendor/codemirror/addon/fold/foldcode.js' type='text/javascript'></script>
<script src='vendor/codemirror/addon/fold/collapserange.js' type='text/javascript'></script>
<script src='vendor/codemirror/addon/format/formatting.js' type='text/javascript'></script>
<script src='vendor/codemirror/addon/edit/matchbrackets.js' type='text/javascript'></script>
<script src='vendor/codemirror/addon/edit/closebrackets.js' type='text/javascript'></script>
<script src='vendor/chosen/chosen.jquery.min.js' type='text/javascript'></script>
  HEREDOC
else
  <<-HEREDOC
<script src='vendor/iframe-phone/iframe-phone.js' type='text/javascript'></script>
<script src='vendor/codemirror/lib/codemirror.js' type='text/javascript'></script>
<script src='vendor/codemirror/mode/javascript/javascript.js' type='text/javascript'></script>
<script src='vendor/codemirror/addon/fold/foldcode.js' type='text/javascript'></script>
<script src='vendor/codemirror/addon/fold/collapserange.js' type='text/javascript'></script>
<script src='vendor/codemirror/addon/format/formatting.js' type='text/javascript'></script>
<script src='vendor/codemirror/addon/edit/matchbrackets.js' type='text/javascript'></script>
<script src='vendor/codemirror/addon/edit/closebrackets.js' type='text/javascript'></script>
<script src='vendor/fingerprintjs/fingerprint.min.js' type='text/javascript'></script>
<script src='vendor/chosen/chosen.jquery.min.js' type='text/javascript'></script>
  HEREDOC
end

LAB_SHUTTERBUG = <<-HEREDOC
<script src='vendor/shutterbug/shutterbug.js' type='text/javascript'></script>
  HEREDOC
LAB_SHUTTERBUG_EMBEDDABLE = LAB_SHUTTERBUG + <<-HEREDOC
<script>
  $(window).load(function () {
    if (typeof Shutterbug !== 'undefined') {
      window.shutterbug = new Shutterbug("#interactive-container", "#image_output") };
    }
  );
</script>
  HEREDOC
