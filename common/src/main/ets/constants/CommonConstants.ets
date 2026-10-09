interface CommonConstantsInterface {
  breakpointsSmName: string;
  breakpointsMdName: string;
  breakpointsLgName: string;
  breakpointsXlName: string;
  breakpointsSmSize: number;
  breakpointsMdSize: number;
  breakpointsLgSize: number;
  breakpointsXlSize: number;
  breakpointsInitializeName: string;
  breakpointIdInitializeName: string;
}

export const commonConstants: CommonConstantsInterface = {
  breakpointsSmName: 'sm',
  breakpointsMdName: 'md',
  breakpointsLgName: 'lg',
  breakpointsXlName: 'xl',
  breakpointsSmSize: 0,
  breakpointsMdSize: 600,
  breakpointsLgSize: 840,
  breakpointsXlSize: 1320,
  breakpointsInitializeName: 'md',
  breakpointIdInitializeName: 'unknown'
};
