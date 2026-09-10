import { Component, OnInit } from '@angular/core';
import { LayoutService } from '../../core/layout.service';

@Component({
  selector: 'app-footer',
  templateUrl: './footer.view.html',
  styleUrls: ['./footer.component.scss'],
})
export class FooterComponent implements OnInit {
  footerContainerCssClasses: string = '';
  currentDateStr: string = new Date().getFullYear().toString();
  constructor(private layout: LayoutService) {}

  ngOnInit(): void {
    this.footerContainerCssClasses =
      this.layout.getStringCSSClasses('footerContainer');
  }
}
