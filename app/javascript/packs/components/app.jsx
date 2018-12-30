import React, { Component } from 'react';
import ReactDOM from 'react-dom';
import PropTypes from 'prop-types';
import Delivery from './delivery';
import partition from 'lodash/partition';
import { parse, startOfToday } from 'date-fns';
import format from '../lib/date-format';
import addMessageHandler from '../lib/service-worker-message';

class App extends Component {
  constructor(props) {
    super(props);

    this.state = {
      currentDate: startOfToday(),
      data: null,
    };

    // TODO: 更新ボタンを作る
    addMessageHandler(({url, cacheName}) => {
      console.log(`updated: ${url} : ${cacheName}`);
      const regexp = new RegExp('/api/deliveries$')
      if (regexp.test(url)) {
        caches.open(cacheName).then((cache) => {
          return cache.match(url);
        }).then(response => response.json())
        .then(data => this.setState({ data }));
      }
    });
  }

  componentDidMount() {
    fetch('/api/deliveries')
      .then(response => response.json())
      .then(data => this.setState({ data }));
  }

  render() {
    const { data, currentDate }  = this.state;
    if (data) {
      const _data = data.map((delivery) => ({ ...delivery, delivery_date: parse(delivery.delivery_date) }))
      const partitioned = partition(_data, (delivery) => delivery.delivery_date < currentDate );
      return (
        <ul className="list-unstyled delivery-list">
          {partitioned[0].map(delivery => <Delivery key={delivery.id} data={delivery}/>)}
          <li className='delivery-list__separator'>
            <div className='delivery-list__separator-line' />
            <div className='delivery-list__separator-date'>
            今日：{format(currentDate, 'YYYY年M月D日(dd)')}
            </div>
            <div className='delivery-list__separator-line' />
        </li>
          {partitioned[1].map(delivery => <Delivery key={delivery.id} data={delivery}/>)}
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
