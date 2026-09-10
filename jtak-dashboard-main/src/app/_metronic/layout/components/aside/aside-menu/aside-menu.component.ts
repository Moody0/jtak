import { Component, OnInit } from '@angular/core';
import { ApplicationMenuGroups } from 'src/app/_metronic/config/settings';
import { environment } from '../../../../../../environments/environment';

@Component({
  selector: 'app-aside-menu',
  templateUrl: './aside-menu.component.html',
  styleUrls: ['./aside-menu.component.scss'],
})
export class AsideMenuComponent implements OnInit {
  appAngularVersion: string = environment.appVersion;
  appPreviewChangelogUrl: string = environment.appVersion;
  applicationMenuGroups = ApplicationMenuGroups;

  constructor() {}

  ngOnInit(): void {}
}
