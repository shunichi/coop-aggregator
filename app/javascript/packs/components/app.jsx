import React, { Component } from 'react';
import ReactDOM from 'react-dom';
import PropTypes from 'prop-types';
import Delivery from './delivery';

class App extends Component {
  constructor(props) {
    super(props);

    this.state = {
      data: null,
    };
  }

  componentDidMount() {
    fetch('/api/deliveries')
      .then(response => response.json())
      .then(data => this.setState({ data }));
  }

  render() {
    const { data }  = this.state;
    if (data) {
      return (
        <ul>
          {data.map(delivery => <Delivery key={delivery.id} delivery={delivery}/>)}
        </ul>
      );
    } else {
      return <div> NO Data </div>;
    }
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

