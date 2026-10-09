interface CommonConstantsInterface {
  breakpointsSmName: string;
  breakpointsMdName: string;
  breakpointsLgName: string;
  breakpointsXlName: string;
  tabSmVertical: boolean;
  tabMdVertical: boolean;
  tabLgVertical: boolean;
  tabXlVertical: boolean;
  tabSmBarWidth: string;
  tabMdBarWidth: string;
  tabLgBarWidth: string;
  tabXlBarWidth: string;
  tabSmBarHeight: string;
  tabMdBarHeight: string;
  tabLgBarHeight: string;
  tabXlBarHeight: string;
  tabContentWidth: string;
  tabContentHeight: string;
  flexTabBarWidth: string;
  flexTabBarHeight: string;
  firstTabChooseIndex: number;
  columnHeight: string;
  tabSize: number;
  gridSize: number;
  breakpointsInitializeName: string;
  columnAspectRatio: number;
  columnTextFontWeight: number;
  rowWidth: string;
  smColTemplate: string;
  mdColTemplate: string;
  lgColTemplate: string;
  xlColTemplate: string;
  initializeTemplate: string;
  breakpointSystemName: string;
}

export const commonConstants: CommonConstantsInterface = {
  breakpointsSmName: 'sm',
  breakpointsMdName: 'md',
  breakpointsLgName: 'lg',
  breakpointsXlName: 'xl',
  tabSmVertical: false,
  tabMdVertical: false,
  tabLgVertical: true,
  tabXlVertical: true,
  tabSmBarWidth: '100%',
  tabMdBarWidth: '100%',
  tabLgBarWidth: '96vp',
  tabXlBarWidth: '96vp',
  tabSmBarHeight: '56vp',
  tabMdBarHeight: '56vp',
  tabLgBarHeight: '60%',
  tabXlBarHeight: '60%',
  tabContentWidth: '100%',
  tabContentHeight: '100%',
  flexTabBarWidth: '100%',
  flexTabBarHeight: '100%',
  firstTabChooseIndex: 0,
  columnHeight: '100%',
  tabSize: 4,
  gridSize: 8,
  breakpointsInitializeName: 'md',
  columnAspectRatio: 16 / 9,
  columnTextFontWeight: 400,
  rowWidth: '100%',
  smColTemplate: '1fr 1fr',
  mdColTemplate: '1fr 1fr 1fr',
  lgColTemplate: '1fr 1fr 1fr 1fr',
  xlColTemplate: '1fr 1fr 1fr 1fr',
  initializeTemplate: '1fr 1fr',
  breakpointSystemName: 'mainBreakpoint'
};
