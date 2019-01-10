import React, { Component } from 'react';
import Delivery from './delivery';
import DeliveryListFooter from './delivery_list_footer';
import partition from 'lodash/partition';
import { parse, startOfToday } from 'date-fns';
import format from '../lib/date-format';
import addMessageHandler from '../lib/service-worker-message';

const Separator = ({currentDate}) => {
  return (
    <li className='delivery-list__separator'>
      <div className='delivery-list__separator-line' />
      <div className='delivery-list__separator-date'>
      今日：{format(currentDate, 'YYYY年M月D日(dd)')}
      </div>
      <div className='delivery-list__separator-line' />
    </li>
    );
};

class DeliveryList extends Component {
  constructor(props) {
    super(props);

    this.state = {
      currentDate: startOfToday(),
      data: null,
      filter: null,
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

  onFilterChanged = (category) => { this.setState({ filter: category }); };

  render() {
    const { data, currentDate, filter }  = this.state;
    if (data) {
      const _data = data.map((delivery) => ({ ...delivery, delivery_date: parse(delivery.delivery_date) }))
      const partitioned = partition(_data, (delivery) => delivery.delivery_date < currentDate );
      return (
        <React.Fragment>
          <ul className="list-unstyled delivery-list">
            {partitioned[0].map(delivery => <Delivery key={delivery.id} data={delivery} category={filter} />)}
            <Separator currentDate={currentDate} />
            {partitioned[1].map(delivery => <Delivery key={delivery.id} data={delivery} category={filter} />)}
          </ul>
          <DeliveryListFooter onFilterChanged={this.onFilterChanged}/>
        </React.Fragment>
      );
    } else {
      return <div> NO Data </div>;
    }
  }
}

export default DeliveryList;
