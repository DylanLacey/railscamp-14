module.exports = function(grunt) {
  grunt.initConfig({
    pkg: grunt.file.readJSON('package.json'),

    watch: {
      sass: {
        files: ['sass/*.scss'],
        tasks: 'sass'
      },
      javascript: {
        files: ['javascript/**/*.js'],
        tasks: 'javascript'
      }
    },

    sass: {
      dist: {
        files: {
          'public/css/screen.css': [
            'components/normalize-css/normalize.css',
            'sass/screen.scss'
          ]
        }
      }
    },

    requirejs: {
      rc15: {
        options: {
          name: "rc15",
          baseUrl: 'javascript',
          mainConfigFile: 'javascript/config.js',
          insertRequire: ["rc15"],
          optimize: "none",
          out: "build/rc15.js"
        }
      }
    },

    uglify: {
      rc15: {
        options: {
          sourceMap: "public/js/rc15.js.map",
          sourceMappingURL: "http://railscamp.herokuapp.com/js/rc15.js.map"
        },
        files: {
          'public/js/rc15.js': ['components/requirejs/require.js', 'build/rc15.js']
        }
      }
    },

    connect: {
      server: {
        options: {
          port: 3000,
          base: './public'
        }
      }
    }
  });

  grunt.registerTask('javascript', ['requirejs:rc15', 'uglify:rc15']);

  grunt.registerTask('default', ['sass', 'javascript']);
  grunt.registerTask('dev', ['connect', 'watch']);

  require('matchdep').filterDev('grunt-*').forEach(grunt.loadNpmTasks);
};
