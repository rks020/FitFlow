import { supabaseClient } from '../supabase-config.js';

export class CustomTimePicker {
    constructor(containerId, inputId, triggerId, onChange) {
        this.containerId = containerId;
        this.inputId = inputId;
        this.triggerId = triggerId;
        this.container = null;
        this.input = null;
        this.trigger = null;
        this.onChange = onChange;
        this.selectedHour = 10;
        this.selectedMinute = 0;
        this.isOpen = false;
    }

    init() {
        this.container = document.getElementById(this.containerId);
        this.input = document.getElementById(this.inputId);
        this.trigger = document.getElementById(this.triggerId);

        if (!this.container || !this.input || !this.trigger) {
            console.error('CustomTimePicker elements not found', { c: this.containerId, i: this.inputId, t: this.triggerId });
            return;
        }

        this.renderDropdown();
        this.setupEventListeners();

        // Sync initial value from input if valid
        if (this.input.value) {
            const [h, m] = this.input.value.split(':');
            if (h && m) {
                this.selectedHour = parseInt(h);
                this.selectedMinute = parseInt(m);
            }
        }
    }

    renderDropdown() {
        const dropdown = this.container.querySelector('.time-picker-dropdown');
        if (!dropdown) return;

        dropdown.innerHTML = `
            <div class="time-columns">
                <div class="time-column" id="${this.containerId}-hours"></div>
                <div class="time-separator">:</div>
                <div class="time-column" id="${this.containerId}-minutes"></div>
            </div>
            <button class="time-picker-done" type="button">Tamam</button>
        `;

        // Generate hours (00-23)
        const hoursColumn = dropdown.querySelector(`#${this.containerId}-hours`);
        for (let i = 0; i < 24; i++) {
            const item = document.createElement('div');
            item.className = 'time-column-item';
            item.textContent = String(i).padStart(2, '0');
            item.dataset.value = i;
            if (i === this.selectedHour) item.classList.add('selected');
            hoursColumn.appendChild(item);
        }

        // Generate minutes (00, 05, 10, ..., 55)
        const minutesColumn = dropdown.querySelector(`#${this.containerId}-minutes`);
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
        const hoursCol = this.container.querySelector(`#${this.containerId}-hours`);
        const minutesCol = this.container.querySelector(`#${this.containerId}-minutes`);

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
        // Toggle on trigger click
        this.trigger.addEventListener('click', (e) => {
            e.stopPropagation();
            this.toggle();
        });

        // Close when clicking outside container or trigger
        document.addEventListener('click', (e) => {
            if (this.isOpen &&
                !this.container.contains(e.target) &&
                !this.trigger.contains(e.target)) {
                this.close();
            }
        });

        // Also update from input on change/blur
        this.input.addEventListener('change', () => {
            if (this.input.value) {
                const [h, m] = this.input.value.split(':');
                if (h && m) {
                    this.selectedHour = parseInt(h);
                    this.selectedMinute = parseInt(m);
                    // Don't call updateDisplay here to avoid loop, just optional render
                    this.renderDropdown();
                }
            }
        });

        const dropdown = this.container.querySelector('.time-picker-dropdown');
        if (!dropdown) return;

        // Hour/minute selection
        const hoursCol = dropdown.querySelector(`#${this.containerId}-hours`);
        const minutesCol = dropdown.querySelector(`#${this.containerId}-minutes`);

        if (hoursCol) {
            hoursCol.addEventListener('click', (e) => {
                if (e.target.classList.contains('time-column-item')) {
                    hoursCol.querySelectorAll('.time-column-item').forEach(i => i.classList.remove('selected'));
                    e.target.classList.add('selected');
                    this.selectedHour = parseInt(e.target.dataset.value);
                    this.updateDisplay();
                }
            });
        }

        if (minutesCol) {
            minutesCol.addEventListener('click', (e) => {
                if (e.target.classList.contains('time-column-item')) {
                    minutesCol.querySelectorAll('.time-column-item').forEach(i => i.classList.remove('selected'));
                    e.target.classList.add('selected');
                    this.selectedMinute = parseInt(e.target.dataset.value);
                    this.updateDisplay();
                }
            });
        }

        // Done button
        const doneBtn = dropdown.querySelector('.time-picker-done');
        if (doneBtn) {
            doneBtn.addEventListener('click', () => {
                this.close();
            });
        }
    }

    toggle() {
        if (this.isOpen) {
            this.close();
        } else {
            this.open();
        }
    }

    open() {
        // Sync before opening in case input was edited manually
        if (this.input.value) {
            const [h, m] = this.input.value.split(':');
            if (h && m) {
                this.selectedHour = parseInt(h);
                this.selectedMinute = parseInt(m);
                this.renderDropdown();
            }
        }

        const dropdown = this.container.querySelector('.time-picker-dropdown');
        dropdown.classList.add('active');
        this.isOpen = true;

        // Small delay to ensure DOM is updated before scrolling
        setTimeout(() => this.scrollToSelected(), 50);
    }

    close() {
        const dropdown = this.container.querySelector('.time-picker-dropdown');
        dropdown.classList.remove('active');
        this.isOpen = false;
    }

    getTimeString() {
        return `${String(this.selectedHour).padStart(2, '0')}:${String(this.selectedMinute).padStart(2, '0')}`;
    }

    updateDisplay() {
        const timeStr = this.getTimeString();

        if (this.input) {
            this.input.value = timeStr;
        }

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
