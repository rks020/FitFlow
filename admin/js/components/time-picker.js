import { supabaseClient } from '../supabase-config.js';

export class CustomTimePicker {
    constructor(elementId, onChange) {
        this.elementId = elementId;
        this.element = null;
        this.onChange = onChange;
        this.selectedHour = 10;
        this.selectedMinute = 0;
        this.isOpen = false;
    }

    init() {
        this.element = document.getElementById(this.elementId);
        if (!this.element) {
            console.error(`CustomTimePicker: Element with id "${this.elementId}" not found`);
            return;
        }
        this.renderDropdown();
        this.setupEventListeners();
    }

    renderDropdown() {
        const dropdown = this.element.querySelector('.time-picker-dropdown');
        if (!dropdown) return;

        dropdown.innerHTML = `
            <div class="time-columns">
                <div class="time-column" id="${this.elementId}-hours"></div>
                <div class="time-separator">:</div>
                <div class="time-column" id="${this.elementId}-minutes"></div>
            </div>
            <button class="time-picker-done" type="button">Tamam</button>
        `;

        // Generate hours (00-23)
        const hoursColumn = dropdown.querySelector(`#${this.elementId}-hours`);
        for (let i = 0; i < 24; i++) {
            const item = document.createElement('div');
            item.className = 'time-column-item';
            item.textContent = String(i).padStart(2, '0');
            item.dataset.value = i;
            if (i === this.selectedHour) item.classList.add('selected');
            hoursColumn.appendChild(item);
        }

        // Generate minutes (00, 05, 10, ..., 55)
        const minutesColumn = dropdown.querySelector(`#${this.elementId}-minutes`);
        for (let i = 0; i < 60; i += 5) {
            const item = document.createElement('div');
            item.className = 'time-column-item';
            item.textContent = String(i).padStart(2, '0');
            item.dataset.value = i;
            if (i === this.selectedMinute) item.classList.add('selected');
            minutesColumn.appendChild(item);
        }
    }

    scrollToSelected() {
        const hoursCol = this.element.querySelector(`#${this.elementId}-hours`);
        const minutesCol = this.element.querySelector(`#${this.elementId}-minutes`);

        const selectedHour = hoursCol?.querySelector('.selected');
        const selectedMinute = minutesCol?.querySelector('.selected');

        if (selectedHour) {
            selectedHour.scrollIntoView({ block: 'center', behavior: 'smooth' });
        }
        if (selectedMinute) {
            selectedMinute.scrollIntoView({ block: 'center', behavior: 'smooth' });
        }
    }

    setupEventListeners() {
        // Open/close dropdown
        const display = this.element.querySelector('.time-display');
        const dropdown = this.element.querySelector('.time-picker-dropdown');

        display.addEventListener('click', (e) => {
            e.stopPropagation();
            this.toggle();
        });

        // Close when clicking outside
        document.addEventListener('click', (e) => {
            if (this.isOpen && !this.element.contains(e.target)) {
                this.close();
            }
        });

        // Hour/minute selection
        const hoursCol = this.element.querySelector(`#${this.elementId}-hours`);
        const minutesCol = this.element.querySelector(`#${this.elementId}-minutes`);

        hoursCol.addEventListener('click', (e) => {
            if (e.target.classList.contains('time-column-item')) {
                hoursCol.querySelectorAll('.time-column-item').forEach(i => i.classList.remove('selected'));
                e.target.classList.add('selected');
                this.selectedHour = parseInt(e.target.dataset.value);
                this.updateDisplay();
            }
        });

        minutesCol.addEventListener('click', (e) => {
            if (e.target.classList.contains('time-column-item')) {
                minutesCol.querySelectorAll('.time-column-item').forEach(i => i.classList.remove('selected'));
                e.target.classList.add('selected');
                this.selectedMinute = parseInt(e.target.dataset.value);
                this.updateDisplay();
            }
        });

        // Done button
        const doneBtn = dropdown.querySelector('.time-picker-done');
        doneBtn.addEventListener('click', () => {
            this.close();
        });
    }

    toggle() {
        if (this.isOpen) {
            this.close();
        } else {
            this.open();
        }
    }

    open() {
        const dropdown = this.element.querySelector('.time-picker-dropdown');
        dropdown.classList.add('active');
        this.isOpen = true;
        // Small delay to ensure DOM is updated before scrolling
        setTimeout(() => this.scrollToSelected(), 50);
    }

    close() {
        const dropdown = this.element.querySelector('.time-picker-dropdown');
        dropdown.classList.remove('active');
        this.isOpen = false;
    }

    getTimeString() {
        return `${String(this.selectedHour).padStart(2, '0')}:${String(this.selectedMinute).padStart(2, '0')}`;
    }

    updateDisplay() {
        const displayElement = this.element.querySelector('.time-display-value');
        const hiddenInput = document.getElementById(this.elementId.replace('-picker', ''));
        const timeStr = this.getTimeString();

        if (displayElement) displayElement.textContent = timeStr;
        if (hiddenInput) hiddenInput.value = timeStr;

        if (this.onChange) this.onChange(timeStr);
    }

    setValue(hour, minute) {
        this.selectedHour = hour;
        this.selectedMinute = minute;
        this.renderDropdown();
        this.updateDisplay();
    }

    getHour() {
        return this.selectedHour;
    }

    getMinute() {
        return this.selectedMinute;
    }
}
