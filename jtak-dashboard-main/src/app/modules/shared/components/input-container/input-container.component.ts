import {
  Component,
  OnInit,
  Input,
  ContentChild,
  ElementRef,
  DoCheck,
} from '@angular/core';

@Component({
  selector: 'app-input-container',
  templateUrl: './input-container.component.html',
})
export class InputContainerComponent implements OnInit, DoCheck {
  @ContentChild('input') child: ElementRef;

  @Input() control: any;

  constructor() {}

  ngOnInit() {}

  ngDoCheck() {
    if (this.control?.invalid) {
      this.child?.nativeElement.classList.add('is-invalid');
    } else {
      this.child?.nativeElement.classList.remove('is-invalid');
    }
  }
}
