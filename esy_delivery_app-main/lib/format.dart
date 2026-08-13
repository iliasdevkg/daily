import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final _currency = NumberFormat.currency(
  locale: 'ru_RU',
  symbol: 'с',
  decimalDigits: 0,
);

String formatPrice(int cents) => _currency.format((cents) / 100);

String unitLabel(String u) => switch (u) {
  'kg' => 'кг',
  'l' => 'л',
  _ => 'шт',
};

// Товар/категориянын slug'ундагы ачкыч сөз боюнча иконка тандайт — эмодзи
// ("стикер") ордуна чыныгы Material иконкалары. Так бир продуктка (алма,
// банан, помидор ж.б.) арналган иконка Material'де жок болгондуктан, окшош
// продуктар бир тектеш иконканы бөлүшөт (мис. бардык жашылча-жемиш — eco);
// түс/градиент/ат аркылуу карточкалар баары бир айырмаланат.
IconData iconForSlug(String slug) {
  const keywords = <String, IconData>{
    // эт азыктары
    'эт-': Icons.kebab_dining_rounded, 'тооп': Icons.kebab_dining_rounded,
    'куриц': Icons.kebab_dining_rounded, 'курин': Icons.kebab_dining_rounded,
    'мясо': Icons.kebab_dining_rounded,
    'рыба': Icons.set_meal_rounded, 'балык': Icons.set_meal_rounded,

    // жумуртка
    'жумуртка': Icons.egg_rounded, 'яйц': Icons.egg_rounded,

    // сүт азыктары
    'сут': Icons.icecream_rounded, 'сүт': Icons.icecream_rounded,
    'молок': Icons.icecream_rounded, 'молоч': Icons.icecream_rounded,
    'йогурт': Icons.icecream_rounded, 'каймак': Icons.icecream_rounded,
    'сыр': Icons.icecream_rounded, 'творог': Icons.icecream_rounded,

    // нан жана камырдан жасалган
    'нан': Icons.bakery_dining_rounded, 'хлеб': Icons.bakery_dining_rounded,
    'булк': Icons.bakery_dining_rounded, 'выпечк': Icons.bakery_dining_rounded,

    // суусундуктар
    'напит': Icons.local_cafe_rounded, 'чай': Icons.local_cafe_rounded,
    'шай': Icons.local_cafe_rounded, 'кофе': Icons.local_cafe_rounded,
    'суу': Icons.local_drink_rounded, 'вода': Icons.local_drink_rounded,

    // жашылча-жемиш
    'алма': Icons.eco_rounded,
    'яблок': Icons.eco_rounded,
    'банан': Icons.eco_rounded,
    'сабиз': Icons.eco_rounded, 'морков': Icons.eco_rounded,
    'пияз': Icons.eco_rounded, 'лук': Icons.eco_rounded,
    'картош': Icons.eco_rounded, 'картоф': Icons.eco_rounded,
    'помидор': Icons.eco_rounded, 'томат': Icons.eco_rounded,
    'овощ': Icons.eco_rounded,
    'фрукт': Icons.eco_rounded,
    'мөмө': Icons.eco_rounded,

    // тиричилик товарлары
    'идиш': Icons.soap_rounded,
    'жуугуч': Icons.soap_rounded,
    'губка': Icons.soap_rounded,
    'жуунуу': Icons.local_laundry_service_rounded,
    'порошок': Icons.local_laundry_service_rounded,
    'жумшаткыч': Icons.local_laundry_service_rounded,
    'туалет': Icons.wc_rounded, 'кагаз': Icons.wc_rounded,
    'салфетка': Icons.wc_rounded, 'сулгу': Icons.wc_rounded,
    'таштанды': Icons.delete_outline_rounded,
    'баштыгы': Icons.delete_outline_rounded,
    'тазалоочу': Icons.cleaning_services_rounded,
    'дезинфекция': Icons.sanitizer_rounded,
    'агартуучу': Icons.sanitizer_rounded,
    'пол': Icons.cleaning_services_rounded,
    'швабра': Icons.cleaning_services_rounded,
    'мопп': Icons.cleaning_services_rounded,
    'веник': Icons.cleaning_services_rounded,
    'шыпыргы': Icons.cleaning_services_rounded,
    'сабын': Icons.soap_rounded,
    'шампунь': Icons.soap_rounded,
    'паста': Icons.medical_services_rounded,
    'унитаз': Icons.wc_rounded, 'кол-кап': Icons.back_hand_rounded,
    'фольга': Icons.science_rounded, 'плёнка': Icons.science_rounded,
    'шырпы': Icons.local_fire_department_rounded,
    'шам': Icons.local_fire_department_rounded,
    'спрей': Icons.water_drop_rounded,
  };
  for (final entry in keywords.entries) {
    if (slug.contains(entry.key)) return entry.value;
  }
  return Icons.shopping_basket_rounded;
}
