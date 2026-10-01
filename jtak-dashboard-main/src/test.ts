// This file is required by karma.conf.js and loads recursively all the .spec and framework files

import 'zone.js/testing';
import { getTestBed } from '@angular/core/testing';
import {
  BrowserDynamicTestingModule,
  platformBrowserDynamicTesting
} from '@angular/platform-browser-dynamic/testing';

// First, initialize the Angular testing environment.
getTestBed().initTestEnvironment(
  BrowserDynamicTestingModule,
  platformBrowserDynamicTesting()
);

// Angular 14's Karma builder discovers selected specs through this context.
// Without it the runner reports success after executing zero tests.
declare const require: { context(path: string, recursive: boolean, pattern: RegExp): any };
const context = require.context('./', true, /\.spec\.ts$/);
context.keys().forEach(context);
