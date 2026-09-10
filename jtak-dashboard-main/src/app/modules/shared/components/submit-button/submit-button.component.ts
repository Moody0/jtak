import { Component, OnInit, Input } from '@angular/core';

@Component({
  selector: 'app-submit-button',
  templateUrl: './submit-button.component.html',
})
export class SubmitButtonComponent implements OnInit {

  @Input() disabled: boolean;
  @Input() label: string;
  @Input() isLoading: boolean;

  constructor() { }

  ngOnInit(): void {
  }

}
