/// <binding Clean='clean' />
"use strict";

var gulp = require("gulp"),
    rimraf = require("rimraf"),
    concat = require("gulp-concat"),
    cleanCss = require("gulp-clean-css"),
    terser = require("gulp-terser");

var paths = {
    webroot: "./wwwroot/"
};

paths.js = paths.webroot + "js/**/*.js";
paths.minJs = paths.webroot + "js/**/*.min.js";
paths.css = paths.webroot + "css/**/*.css";
paths.minCss = paths.webroot + "css/**/*.min.css";
paths.concatJsDest = paths.webroot + "js/site.min.js";
paths.concatCssDest = paths.webroot + "css/site.min.css";

function cleanJs(cb) {
    rimraf(paths.concatJsDest, cb);
}

function cleanCssTask(cb) {
    rimraf(paths.concatCssDest, cb);
}

function minJs() {
    return gulp.src([paths.js, "!" + paths.minJs], { base: "." })
        .pipe(concat(paths.concatJsDest))
        .pipe(terser())
        .pipe(gulp.dest("."));
}

function minCss() {
    return gulp.src([paths.css, "!" + paths.minCss])
        .pipe(concat(paths.concatCssDest))
        .pipe(cleanCss())
        .pipe(gulp.dest("."));
}

gulp.task("clean:js", cleanJs);
gulp.task("clean:css", cleanCssTask);
gulp.task("clean", gulp.parallel(cleanJs, cleanCssTask));

gulp.task("min:js", minJs);
gulp.task("min:css", minCss);
gulp.task("min", gulp.parallel(minJs, minCss));
