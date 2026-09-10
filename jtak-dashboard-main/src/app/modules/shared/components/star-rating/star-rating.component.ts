import { Component, Input, OnInit } from '@angular/core';

@Component({
  selector: 'app-star-rating',
  templateUrl: './star-rating.component.html',
})
export class StarRatingComponent implements OnInit {
  @Input() rate: number;
  rates = [
    'far fa-star',
    'far fa-star',
    'far fa-star',
    'far fa-star',
    'far fa-star',
  ];

  constructor() {}

  ngOnInit(): void {
    this.rate = Math.round(this.rate);
    this.rates = this.rates.map((rate, index) => {
      if (this.rate > index) {
        return 'fas fa-star';
      }

      return 'far fa-star';
    });
  }
}
