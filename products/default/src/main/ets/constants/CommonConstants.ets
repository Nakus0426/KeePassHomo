interface CommonConstantsInterface {
  columnXs: number;
  columnSm: number;
  columnMd: number;
  columnLg: number;
  spanXs: number;
  spanSm: number;
  spanMd: number;
  spanLg: number;
  offsetXs: number;
  offsetSm: number;
  offsetMd: number;
  offsetLg: number;
  listFontWeight: number;
  listWidth: string;
  listItemWidth: string;
  columnHeight: string;
  bundleName: string;
  abilityName: string;
  breakpointsInitializeName: string;
  locationCapability: string;
  breakpointSystemName: string;
  systemColumnHeight: string;
  systemColumnWidth: string;
  systemRowWidth: string;
  textFontWeight: number;
  adaptiveColumnWidth: string;
  adaptiveColumnHeight: string;
  adaptiveFlexibleColumnWidth: string;
  adaptiveFlexShrink: number;
}

export const commonConstants: CommonConstantsInterface = {
  columnXs: 4,

  columnSm: 4,

  columnMd: 8,

  columnLg: 12,

  spanXs: 4,

  spanSm: 4,

  spanMd: 4,

  spanLg: 4,

  offsetXs: 0,

  offsetSm: 0,

  offsetMd: 2,

  offsetLg: 4,

  listFontWeight: 500,

  listWidth: '100%',

  listItemWidth: '100%',

  columnHeight: '100%',

  bundleName: 'com.example.myapplication',

  abilityName: 'ResponsiveLayoutItemAbility',

  breakpointsInitializeName: 'md',

  locationCapability: 'SystemCapability.Location.Location.Core',

  breakpointSystemName: 'mainBreakpoint',

  systemColumnHeight: '100%',

  systemColumnWidth: '100%',

  systemRowWidth: '100%',

  textFontWeight: 500,

  adaptiveColumnWidth: '100%',

  adaptiveColumnHeight: '100%',

  adaptiveFlexibleColumnWidth: '100%',

  adaptiveFlexShrink: 1
};
