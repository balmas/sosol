<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    version="1.0"
    xmlns:cts="http://chs.harvard.edu/xmlns/cts3/ti">
    
    <xsl:output method="text"/>
    <xsl:template match="/">
        <xsl:for-each select="//cts:textgroup">
            <xsl:variable name="group" select="@projid"/>
            <xsl:variable name="groupname" select="cts:groupname[1]"/>
            <xsl:variable name="group_prefix" select="substring-before($group,':')"/>
            <xsl:message>Group <xsl:value-of select="$group"/></xsl:message>
            <xsl:for-each select="cts:work">
                <xsl:variable name="work_prefix" select="substring-before(@projid,':')"/>
                <xsl:variable name="work">    
                    <xsl:choose>
                        <xsl:when test="$work_prefix = $group_prefix">
                            <xsl:value-of select="substring-after(@projid,':')"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="@projid"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                <xsl:for-each select="cts:edition">
                    <xsl:variable name="edition_prefix" select="substring-before(@projid,':')"/>
                    <xsl:variable name="edition_label" select="cts:label"/>
                    <xsl:variable name="edition">
                        <xsl:choose>
                            <xsl:when test="$edition_prefix = $work_prefix">
                                <xsl:value-of select="substring-after(@projid,':')"/>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:value-of select="@projid"/>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:variable>
                    <xsl:variable name="urn" select="translate(concat($group,'.',$work,'.',$edition),',','__')"/>
                    <xsl:value-of select="concat($edition_label,' (',$urn,')','|','urn:cts:',$urn,',')"/>
                </xsl:for-each>
            </xsl:for-each>
        </xsl:for-each>
    </xsl:template>
    
    <xsl:template match="*"/>
</xsl:stylesheet>