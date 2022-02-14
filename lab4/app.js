
// const axios = require('axios');

var app = new Vue({
    el: '#app',
    data: {
        sensor: {
            name: "",
            location: "",
            threshold: null,
            phone: ""
        },
        sensorInput: {
            name: null,
            location: null,
            threshold: null,
            phone: null
        },
        measurements: []
    },

    mounted: function() {
        this.getTemperatures();
        this.getSensorProfile();
        this.startGetTemperaturesInterval();
    },

    computed: {
        headMeasurement: function() {
            return this.measurements[0]
        },
        tailMeasurements: function() {
            return this.measurements.slice(1)
        }
    },

    methods: {
        newMeasurement: function(temperature, location, date, time, threshold) {
            this.measurements.unshift({
                temperature: temperature,
                location: location,
                date: date,
                time: time,
                threshold: threshold
            })
        },

        newViolation: function(temperature, date, time) {
            return null
        },

        sensorToInput: function() {
            this.sensorInput.name = this.sensor.name;
            this.sensorInput.phone = this.sensor.phone;
            this.sensorInput.threshold = this.sensor.threshold;
            this.sensorInput.location = this.sensor.location;
        },

        inputToSensor: function() {
            this.sensor.name = this.sensorInput.name;
            this.sensor.phone = this.sensorInput.phone;
            this.sensor.threshold = this.sensorInput.threshold;
            this.sensor.location = this.sensorInput.location;
        },

        nullSensorInput: function() {
            this.sensorInput = {
                name: null,
                location: null,
                threshold: null,
                phone: null
            }
        },

        startModal: function() {
            this.sensorToInput()
        },

        hideModal: function() {
            var modalEl = document.getElementById("editSensorModal");
            console.log(modalEl);
            var modal = bootstrap.Modal.getInstance(modalEl);
            console.log(modal);
            modal.hide();
        },

        submitSensorChanges: function() {
            // Submit
            // this.inputToSensor();
            this.setSensorProfile();
            this.hideModal();
            this.sensorToInput();  
        },

        cancelSensorChanges: function() {
            console.log("CANCEL");
            this.hideModal();   
            this.nullSensorInput();
        },

        editModalStart: function() {
            this.sensorToInput;
        },

        setSensorProfile: function() {

        },

        getSensorProfile: function() {
            let vm = this;
            axios.get("http://localhost:3000/sky/cloud/ckywg9dfp008z1ntx3vm1bkii/sensor_profile/sensor_profile")
            .then(function(response) {
                console.log("YAY")
                vm.sensor = response.data;
            })
            .catch(function(err) {
                console.log("FAIL")
                console.log(err);
            });
        },

        getTemperatures: function() {
            let vm = this;
            axios.get("http://localhost:3000/sky/cloud/ckywg9dfp008z1ntx3vm1bkii/temperature_store/temperatures")
            .then(function(response) {
                // console.log(response.data[0].timestamp.split('T'))
                let mapped = response.data.map(x => {
                    return {
                        temperature: x.temperature,
                        date: x.timestamp.split(['T'])[0],
                        time: x.timestamp.split(['T'])[1].split('.')[0]
                    }
                });
                vm.measurements = mapped.reverse()
                console.log(vm.measurements)
            })
            .catch(function(err) {
                console.log(err);
            });
        },

        setSensorProfile: function() {
            let vm = this;
            let url = `http://localhost:3000/sky/event/ckywg9dfp008z1ntx3vm1bkii/1556/sensor/profile_updated?threshold=${vm.sensorInput.threshold}&phone=${vm.sensorInput.phone}`
            axios.post(url)
            .then(function(response) {
                console.log('pass');
                console.log(response);
                vm.getSensorProfile();
            })
            .catch(function(err) {
                console.log("ERR setTemperatures")
                console.log(err);
            });
        },

        startGetTemperaturesInterval: function() {
            let vm = this;          
            this.getTemperaturesInterval = setInterval(function(){
                vm.getTemperatures();
            }, 5000);
        }
    }
})