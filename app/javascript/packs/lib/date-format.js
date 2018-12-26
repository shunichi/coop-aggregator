import { format } from 'date-fns';
import ja from 'date-fns/locale/ja';

const _format = function (date, formatStr) {
  return format(date, formatStr, { locale: ja });
}
export default _format;
