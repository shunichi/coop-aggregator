import React, { Component } from 'react';
import ReactDOM from 'react-dom';
import DeliveryList from './delivery_list';

class App extends Component {
  constructor(props) {
    super(props);
  }

  render() {
    return <DeliveryList />;
  }
}

document.addEventListener('DOMContentLoaded', () => {
  const appRoot = document.getElementById('app');
  if (appRoot) {
    ReactDOM.render(
      <App />,
      appRoot,
    )
  }
})
