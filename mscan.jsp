<%@ page import="java.net.URL" %>
<%@ page import="java.lang.reflect.Field" %>
<%@ page import="org.apache.catalina.core.StandardWrapper" %>
<%@ page import="java.lang.reflect.Method" %>
<%@ page import="org.apache.catalina.core.StandardContext" %>
<%@ page import="java.util.*" %>
<%--
  Created by IntelliJ IDEA.
  User: nemuikuma
  Date: 2023/2/13
  Time: 15:02
  To change this template use File | Settings | File Templates.
--%>
<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<html>
<head>
    <title>tomcat memshell cleaner</title>
</head>
<body>
<%!
    Set<String> EvilServletName = new HashSet<>();
    Set<String> EvilFilterName = new HashSet<>();

    private HashMap<String, String> getServletMaps(HttpServletRequest request) throws Exception {
        Object standardContext = getStandardContext(request);
        Field  servletMappings = standardContext.getClass().getDeclaredField("servletMappings");
        servletMappings.setAccessible(true);
        return (HashMap<String, String>) servletMappings.get(standardContext);
    }

    private HashMap<String, Object> getChildren(HttpServletRequest request) throws Exception {
        Object standardContext = getStandardContext(request);
        Field  _children       = standardContext.getClass().getSuperclass().getDeclaredField("children");
        _children.setAccessible(true);
        return (HashMap<String, Object>) _children.get(standardContext);
    }

    private HashMap<String, Object> getFilterConfig(HttpServletRequest request) throws Exception {
        StandardContext o               = (StandardContext) getStandardContext(request);
        Field           __filterConfigs = o.getClass().getDeclaredField("filterConfigs");
        __filterConfigs.setAccessible(true);
        return (HashMap<String, Object>) __filterConfigs.get(o);
    }

    private Object getFilterMap(HttpServletRequest request) throws Exception {
        StandardContext o                 = (StandardContext) getStandardContext(request);
        Field           __filterMapsField = o.getClass().getDeclaredField("filterMaps");
        __filterMapsField.setAccessible(true);
        return __filterMapsField.get(o);
    }

    private Object[] getFilterMaps(HttpServletRequest request) throws Exception {
        Object   filterMaps  = getFilterMap(request);
        Object[] filterArray = null;
        try { // tomcat 789
            Field _array = filterMaps.getClass().getDeclaredField("array");
            _array.setAccessible(true);
            filterArray = (Object[]) _array.get(filterMaps);
        } catch (Exception e) { // tomcat 6
            filterArray = (Object[]) filterMaps;
        }
        return filterArray;
    }

    public String[] getURLPatterns(Object filterMap) throws Exception {
        Method getFilterName = filterMap.getClass().getDeclaredMethod("getURLPatterns");
        getFilterName.setAccessible(true);
        return (String[]) getFilterName.invoke(filterMap, null);
    }

    public Object getStandardContext(HttpServletRequest request) throws Exception {
        StandardContext o              = null;
        ServletContext  servletContext = request.getServletContext();

        while (o == null) {
            Field f = servletContext.getClass().getDeclaredField("context");
            f.setAccessible(true);
            Object object = f.get(servletContext);
            if (object instanceof ServletContext) {
                servletContext = (ServletContext) object;
            } else if (object instanceof StandardContext) {
                o = (StandardContext) object;
            }
        }
        return o;
    }

    public String getClassPath(Class<?> clazz) {
        if (clazz != null) {
            String className = clazz.getName();
            String classPath = className.replace(".", "/") + ".class";
            URL    url       = clazz.getClassLoader().getResource(classPath);
            if (url == null) {
                return null;
            } else {
                return url.toString();
            }
        }
        return null;
    }

    public synchronized StringBuffer getServletInfo(HttpServletRequest request, HashMap<String, String> servletMaps) throws Exception {
        HashMap<String, Object> children = getChildren(request);
        StringBuffer            sb       = new StringBuffer();
        sb.append("<center><div><h3>Servlet Name:</h3>")
                .append("<table border=\"1\" cellspacing=\"0\" width=\"95%\" style=\"table-layout:fixed;word-break:break-all;background:#f2f2f2\">\n" +
                        "    <thead>\n" +
                        "        <th width=\"10%\">Servlet name</th>\n" +
                        "        <th width=\"20%\">Servlet classLoader</th>\n" +
                        "        <th width=\"10%\">Servlet path</th>\n" +
                        "        <th width=\"20%\">Servlet class</th>\n" +
                        "        <th width=\"25%\">Servlet class file path</th>\n" +
                        "    </thead>\n" +
                        "    <tbody><tr>");
        for (Map.Entry<String, String> map : servletMaps.entrySet()) {
            String          servletMapPath = map.getKey();
            String          servletName    = map.getValue();
            StandardWrapper wrapper        = (StandardWrapper) children.get(servletName);

            Class servletClass = null;
            try {
                servletClass = Class.forName(wrapper.getServletClass());
            } catch (Exception e) {
                Object servlet = wrapper.getServlet();
                if (servlet != null) {
                    servletClass = servlet.getClass();
                }
            }
            if (getClassPath(servletClass) == null) {
                EvilServletName.add(servletName);
            }
            sb.append("<td style=\"text-align:center\">")
                    .append(servletName)
                    .append("</td><td>")
                    .append(servletClass.getClassLoader().getClass().toString().replace("class ", ""))
                    .append("</td><td>")
                    .append(servletMapPath)
                    .append("</td><td>")
                    .append(servletClass.getName())
                    .append("</td><td>")
                    .append(getClassPath(servletClass))
                    .append("</td></tr>");
        }
        sb.append("</tbody></table></div></center>");
        return sb;
    }

    public synchronized StringBuffer getListenerInfo(HttpServletRequest request) throws Exception {
        StandardContext o               = (StandardContext) getStandardContext(request);
        Object[]        listeners       = o.getApplicationEventListeners();
        Field           servletMapField = o.getClass().getDeclaredField("servletMappings");
        StringBuffer    sb              = new StringBuffer();
        sb.append("<center><div><h3>Listener Name:</h3>")
                .append("<table border=\"1\" cellspacing=\"0\" width=\"95%\" style=\"table-layout:fixed;word-break:break-all;background:#f2f2f2\">\n" +
                        "    <thead>\n" +
                        "        <th width=\"10%\">Listener name</th>\n" +
                        "        <th width=\"20%\">Listener classLoader</th>\n" +
                        "        <th width=\"25%\">Listener class file path</th>\n" +
                        "    </thead>\n" +
                        "    <tbody><tr>");
        servletMapField.setAccessible(true);
        if (listeners.length != 0) {
            for (Object obj : listeners) {
                sb.append("<td style=\"text-align:center\">")
                        .append(obj.getClass().getName())
                        .append("</td><td>")
                        .append(obj.getClass().getClassLoader().getClass())
                        .append("</td><td>")
                        .append(getClassPath(obj.getClass()))
                        .append("</td></tr>");
            }
        }
        sb.append("</tbody></table></div></center>");
        return sb;
    }

    public synchronized StringBuffer getFilterInfo(HttpServletRequest request) throws Exception {
        HashMap<String, Object> filterConfigs = getFilterConfig(request);
        Object[]                filterArray   = getFilterMaps(request);
        StringBuffer            sb            = new StringBuffer();
        sb.append("<center><div><h3>Filter Name:</h3>")
                .append("<table border=\"1\" cellspacing=\"0\" width=\"95%\" style=\"table-layout:fixed;word-break:break-all;background:#f2f2f2\">\n" +
                        "    <thead>\n" +
                        "        <th width=\"10%\">Filter name</th>\n" +
                        "        <th width=\"20%\">Filter classLoader</th>\n" +
                        "        <th width=\"10%\">Patern</th>\n" +
                        "        <th width=\"20%\">Filter class</th>\n" +
                        "        <th width=\"25%\">Filter class file path</th>\n" +
                        "    </thead>\n" +
                        "    <tbody><tr>");
        for (Object fm : filterArray) {
            Method getFilterName = fm.getClass().getDeclaredMethod("getFilterName");
            getFilterName.setAccessible(true);

            String filterName      = (String) getFilterName.invoke(fm, null);
            Object appFilterConfig = filterConfigs.get(filterName);
            Field  _filter         = appFilterConfig.getClass().getDeclaredField("filter");
            _filter.setAccessible(true);
            Object filter = _filter.get(appFilterConfig);

            if (getClassPath(filter.getClass()) == null) {
                EvilFilterName.add(filterName);
            }

            sb.append("<td style=\"text-align:center\">")
                    .append(filterName)
                    .append("</td><td>")
                    .append(filter.getClass().getClassLoader())
                    .append("</td><td>")
                    .append(Arrays.toString(getURLPatterns(fm)))
                    .append("</td><td>")
                    .append(fm.getClass())
                    .append("</td><td>")
                    .append(getClassPath(filter.getClass()))
                    .append("</td></tr>");
        }
        sb.append("</tbody></table></div></center>");
        return sb;
    }

    public synchronized void flushListener(HttpServletRequest request) {
        try {
            StandardContext standardContext = (StandardContext) getStandardContext(request);
            standardContext.listenerStop();
            standardContext.listenerStart();
        } catch (Exception ignored) {
        }
    }

    public synchronized void deleteServlet(HttpServletRequest request, String servletName) throws Exception {
        HashMap<String, Object> childs      = getChildren(request);
        Object                  objChild    = childs.get(servletName);
        String                  urlPattern  = null;
        HashMap<String, String> servletMaps = getServletMaps(request);
        for (Map.Entry<String, String> servletMap : servletMaps.entrySet()) {
            if (servletMap.getValue().equals(servletName)) {
                urlPattern = servletMap.getKey();
                break;
            }
        }

        if (urlPattern != null) {
            Object standardContext      = getStandardContext(request);
            Method removeServletMapping = standardContext.getClass().getDeclaredMethod("removeServletMapping", new Class[]{String.class});
            removeServletMapping.setAccessible(true);
            removeServletMapping.invoke(standardContext, urlPattern);
            Method removeChild = standardContext.getClass().getDeclaredMethod("removeChild", new Class[]{org.apache.catalina.Container.class});
            removeChild.setAccessible(true);
            removeChild.invoke(standardContext, objChild);
        }
    }

    public synchronized void deleteFilter(HttpServletRequest request, String filterName) throws Exception {
        Object standardContext = getStandardContext(request);
        // org.apache.catalina.core.StandardContext#removeFilterDef
        HashMap<String, Object> filterConfig    = getFilterConfig(request);
        Object                  appFilterConfig = filterConfig.get(filterName);
        Field                   _filterDef      = appFilterConfig.getClass().getDeclaredField("filterDef");
        _filterDef.setAccessible(true);
        Object filterDef    = _filterDef.get(appFilterConfig);
        Class  clsFilterDef = null;
        try {
            // Tomcat 8
            clsFilterDef = Class.forName("org.apache.tomcat.util.descriptor.web.FilterDef");
        } catch (Exception e) {
            // Tomcat 7
            clsFilterDef = Class.forName("org.apache.catalina.deploy.FilterDef");
        }
        Method removeFilterDef = standardContext.getClass().getDeclaredMethod("removeFilterDef", new Class[]{clsFilterDef});
        removeFilterDef.setAccessible(true);
        removeFilterDef.invoke(standardContext, filterDef);

        // org.apache.catalina.core.StandardContext#removeFilterMap
        Class clsFilterMap = null;
        try {
            // Tomcat 8
            clsFilterMap = Class.forName("org.apache.tomcat.util.descriptor.web.FilterMap");
        } catch (Exception e) {
            // Tomcat 7
            clsFilterMap = Class.forName("org.apache.catalina.deploy.FilterMap");
        }
        Object[] filterMaps = getFilterMaps(request);
        for (Object filterMap : filterMaps) {
            Field _filterName = filterMap.getClass().getDeclaredField("filterName");
            _filterName.setAccessible(true);
            String filterName0 = (String) _filterName.get(filterMap);
            if (filterName0.equals(filterName)) {
                Method removeFilterMap = standardContext.getClass().getDeclaredMethod("removeFilterMap", new Class[]{clsFilterMap});
                removeFilterDef.setAccessible(true);
                removeFilterMap.invoke(standardContext, filterMap);
            }
        }
    }

    public synchronized void clearAllEvilServlet(HttpServletRequest request) throws Exception {
        if (!EvilServletName.isEmpty()) {
            for (Object name : EvilServletName.toArray()) {
                deleteServlet(request, name.toString());
            }
        }
    }

    public synchronized void clearAllEvilFilter(HttpServletRequest request) throws Exception {
        if (!EvilFilterName.isEmpty()) {
            for (Object name : EvilFilterName.toArray()) {
                deleteFilter(request, name.toString());
            }
        }
    }

    public void warnMsgChange(StringBuffer info, String target, String change) {
        int start = info.indexOf(target);
        if (start != -1) {
            info.replace(start, start + target.length(), change);
        }
    }
%>
<%
    out.write("<center><h2>Tomcat memshell scanner x.x.x</h2></center>");
    out.write("<center><a style=\"padding:10px\" href=\"" + request.getRequestURI() + "?delservlet\">clear Servlet</a>");
    out.write("<a style=\"padding:10px\" href=\"" + request.getRequestURI() + "?delfilter\">clear Filter</a>");
    out.write("<a style=\"padding:10px\" href=\"" + request.getRequestURI() + "?flush\">clear Listener</a>");
    out.write("</center>");
    try {
        HashMap<String, String> servlets = getServletMaps(request);

        StringBuffer servletInfo  = getServletInfo(request, servlets);
        StringBuffer listenerInfo = getListenerInfo(request);
        StringBuffer filterInfo   = getFilterInfo(request);

        warnMsgChange(servletInfo, "<td>null</td>", "<td style='color:red'>class not found</td>");
        warnMsgChange(listenerInfo, "<td>null</td>", "<td style='color:red'>class not found</td>");
        warnMsgChange(filterInfo, "<td>null</td>", "<td style='color:red'>class not found</td>");

        out.write(filterInfo.toString());
        out.write(listenerInfo.toString());
        out.write(servletInfo.toString());

        if (request.getParameter("flush") != null) {
            flushListener(request);
            out.flush();
        }
        if (request.getParameter("delservlet") != null) {
            clearAllEvilServlet(request);
            out.flush();
        }
        if (request.getParameter("delfilter") != null) {
            clearAllEvilFilter(request);
            out.flush();
        }
    } catch (Exception e) {
        System.out.println(e);
    }


%>
</body>
</html>
