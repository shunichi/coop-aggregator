import React from 'react';
import PropTypes from 'prop-types';
import format from '../lib/date-format';
import Item from './item';

const Delivery = (props) => {
  const { data } = props;
  const date = data.delivery_date;
  const dateStr = format(date, 'YYYY年M月D日(dd)');
  const flat_items = data.items.reduce((result, item) => {
    result = result.concat([item]);
    if (item.childItems) result = result.concat(item.childItems);
    return result;
  }, [])

  return (
    <li className={'delivery-header ' + data.shop}>
      <div className='delivery-header__content'>
        {dateStr}：{data.shop_display_name} {data.name}
      </div>
      <ul className='list-unstyled'>
        {flat_items.map(item => <Item key={item.id} data={item} shopName={data.shop}/>)}
      </ul>
    </li>
  );
};

Delivery.propTypes = {
  data: PropTypes.object,
};

export default Delivery;
