import React from 'react';
import PropTypes from 'prop-types';
import format from '../lib/date-format';
import Item from './item';

const categoryFilter = (items, category) => {
  if (!category) return items;
  return items.map((item) => {
    const childItems = item.childItems ? categoryFilter(item.childItems, category) : [];
    if (childItems.length > 0) {
      return { ...item, childItems: childItems };
    } else if (item.category === category) {
      return item;
    }
    return null;
  }).filter(item => item);
};

const Delivery = (props) => {
  const { data, category } = props;
  const date = data.delivery_date;
  const dateStr = format(date, 'yyyy年M月d日(E)');
  const items = categoryFilter(data.items, category);
  return (
    <li className={'delivery-header ' + data.shop}>
      <div className='delivery-header__content'>
        {dateStr}：{data.shop_display_name} {data.name}
      </div>
      <ul className='list-unstyled'>
        {items.map(item => <Item key={item.id} data={item} shopName={data.shop}/>)}
      </ul>
    </li>
  );
};

Delivery.propTypes = {
  data: PropTypes.object,
};

export default Delivery;
